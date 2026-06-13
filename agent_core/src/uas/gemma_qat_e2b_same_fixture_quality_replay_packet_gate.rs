//! Gemma QAT E2B same-fixture quality replay packet gate.
//!
//! This primitive consumes the E2B first-token artifact reconciliation contract
//! and defines the fail-closed packet required before a future reconciled token
//! can become same-fixture quality evidence. It is metadata-only: no fixture,
//! artifact, scorer, model, runtime, or provider bytes are opened or executed.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    GemmaFamilyRuntimeLane, GemmaQatQualityTaskFamily, ProStatus, ProductBuild, UasAddress,
    UasKind, GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
    GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_ID,
    GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_UPSTREAM_REF,
    GEMMA_QAT_E2B_SOURCE_REVISION, GEMMA_QAT_QUALITY_TASK_FAMILIES,
    GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH, GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME,
    GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID,
};

pub const GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_ID: &str =
    "F-GemmaQATE2BSameFixtureQualityReplayPacketGate";
pub const GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_CURSOR: &str =
    "gemma_qat_e2b_same_fixture_quality_replay_packet_gate";
pub const GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_NEXT_CURSOR: &str =
    "gemma_qat_e2b_runtime_router_admission_packet_gate";
pub const GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate/result.json#F-GemmaQATE2BFirstTokenRuntimeArtifactReviewReconciliationGate";

const UPSTREAM_RECONCILIATION_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_qat_e2b_same_fixture_quality_replay_packet_gate/";
const PACKET_CARD_ID: &str = "gemma-e2b-gguf-same-fixture-quality-replay-packet-gate";
const FUTURE_QUALITY_PACKET_NAME: &str = "owner-approved-e2b-gguf-same-fixture-quality-packet-v1";
const FIXTURE_PACK_DIGEST: &str = "fixture_pack:sha256:gemma-e2b-same-fixture-quality-pack-v1";
const SCORER_BUNDLE_DIGEST: &str = "scorer_bundle:sha256:gemma-e2b-deterministic-quality-scorer-v1";
const MAX_METADATA_BYTES: u64 = 288 * 1024;

const REQUIRED_PACKET_FIELDS: &[&str] = &[
    "upstream_reconciliation_artifact_digest",
    "runtime_artifact_reconciliation_decision_digest",
    "owner_approval_digest",
    "owner_manifest_digest",
    "canonical_path_digest",
    "model_file_sha256",
    "model_file_size_bytes",
    "llama_cpp_binary_sha256",
    "llama_cpp_version_digest",
    "command_template_digest",
    "environment_allowlist_digest",
    "same_fixture_pack_digest",
    "fixture_split_digest",
    "task_family_digest",
    "prompt_digest_policy",
    "context_digest_policy",
    "tool_schema_digest",
    "expected_output_shape_digest",
    "redacted_final_output_digest",
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
    "rollback_digest",
    "run_event_log_digest",
    "answer_packet_digest",
    "abstention_digest",
    "non_promotion_digest",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_reconciliation_artifact",
    "upstream_reconciliation_artifact_digest_mismatch",
    "missing_owner_approval_digest",
    "missing_owner_manifest_digest",
    "missing_model_file_digest",
    "missing_llama_cpp_binary_digest",
    "wrong_selected_model",
    "wrong_runtime_lane",
    "wrong_fixture_pack",
    "missing_task_family",
    "missing_prompt_digest_policy",
    "missing_context_digest_policy",
    "missing_tool_schema_digest",
    "missing_expected_output_shape_digest",
    "missing_redacted_final_output_digest",
    "missing_deterministic_scorer_bundle",
    "model_graded_primary",
    "hidden_judge",
    "raw_prompt_retained",
    "raw_context_retained",
    "raw_output_retained",
    "raw_judge_retained",
    "fixture_payload_opened_in_default_loop",
    "runtime_artifact_read_in_default_loop",
    "scorer_executed_in_default_loop",
    "runtime_replay_attempted_in_packet_gate",
    "cache_reuse_without_lineage",
    "contamination_check_missing",
    "cache_deletion_missing",
    "missing_timeout_cancel",
    "missing_rollback",
    "missing_run_event_log",
    "missing_answer_packet",
    "missing_abstention",
    "runtime_router_mutation",
    "system_g_mutation",
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
    "quality_claim_before_packet",
    "benchmark_claimed_as_fit",
];

// UAS: uas:gemma-qat-e2b-same-fixture-quality-packet-gate:status
// Plane: Verification.
// Residency: metadata-only packet gate status; no fixture/model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatE2bSameFixtureQualityReplayPacketGateStatus {
    QualityPacketContractOnly,
}

// UAS: uas:gemma-qat-e2b-same-fixture-quality-packet-gate:spec
// Plane: Controller + Verification.
// Residency: future quality packet contract only; no replay or scorer runs.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bSameFixtureQualityReplayPacketGate {
    pub upstream_reconciliation_ref: String,
    pub upstream_reconciliation_id: String,
    pub upstream_owner_approved_probe_ref: String,
    pub artifact_root_prefix: String,
    pub packet_card_id: String,
    pub future_quality_packet_name: String,
    pub selected_model_id: String,
    pub source_revision: String,
    pub required_filename: String,
    pub expected_file_size_bytes: u64,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub command_path: String,
    pub fixture_pack_digest: String,
    pub scorer_bundle_digest: String,
    pub task_families: Vec<GemmaQatQualityTaskFamily>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_packet_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub upstream_reconciliation_digest_required: bool,
    pub owner_approval_digest_required: bool,
    pub owner_manifest_digest_required: bool,
    pub canonical_path_digest_required: bool,
    pub model_file_digest_match_required: bool,
    pub llama_cpp_binary_digest_match_required: bool,
    pub llama_cpp_version_digest_match_required: bool,
    pub same_fixture_pack_digest_required: bool,
    pub held_out_split_bound: bool,
    pub prompt_context_tool_digests_required: bool,
    pub redacted_final_output_digest_required: bool,
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
    pub future_quality_packet_present: bool,
    pub future_quality_packet_bytes_read: u64,
    pub accepted_quality_packet_count: u64,
    pub quality_replay_performed_count: u64,
    pub fixture_payload_bytes_opened: u64,
    pub runtime_artifact_bytes_read: u64,
    pub scorer_executions: u64,
    pub benchmark_runs: u64,
    pub command_armed: bool,
    pub command_executed: bool,
    pub runtime_replay_performed: bool,
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
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub status: GemmaQatE2bSameFixtureQualityReplayPacketGateStatus,
    pub next_cursor: String,
}

impl GemmaQatE2bSameFixtureQualityReplayPacketGate {
    pub fn canonical(upstream_reconciliation_ref: impl Into<String>) -> Self {
        Self {
            upstream_reconciliation_ref: upstream_reconciliation_ref.into(),
            upstream_reconciliation_id:
                GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_ID.to_string(),
            upstream_owner_approved_probe_ref:
                GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_UPSTREAM_REF
                    .to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            packet_card_id: PACKET_CARD_ID.to_string(),
            future_quality_packet_name: FUTURE_QUALITY_PACKET_NAME.to_string(),
            selected_model_id: GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID.to_string(),
            source_revision: GEMMA_QAT_E2B_SOURCE_REVISION.to_string(),
            required_filename: GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME.to_string(),
            expected_file_size_bytes: GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
            runtime_lane: GemmaFamilyRuntimeLane::GgufLlamaCpp,
            command_path: GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH.to_string(),
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
            upstream_reconciliation_digest_required: true,
            owner_approval_digest_required: true,
            owner_manifest_digest_required: true,
            canonical_path_digest_required: true,
            model_file_digest_match_required: true,
            llama_cpp_binary_digest_match_required: true,
            llama_cpp_version_digest_match_required: true,
            same_fixture_pack_digest_required: true,
            held_out_split_bound: true,
            prompt_context_tool_digests_required: true,
            redacted_final_output_digest_required: true,
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
            future_quality_packet_present: false,
            future_quality_packet_bytes_read: 0,
            accepted_quality_packet_count: 0,
            quality_replay_performed_count: 0,
            fixture_payload_bytes_opened: 0,
            runtime_artifact_bytes_read: 0,
            scorer_executions: 0,
            benchmark_runs: 0,
            command_armed: false,
            command_executed: false,
            runtime_replay_performed: false,
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
            metadata_bytes: 176_000,
            rollback_ref: "rollback:gemma_qat_e2b_same_fixture_quality_replay_packet_gate"
                .to_string(),
            run_event_log_ref:
                "run_event_log:gemma_qat_e2b_same_fixture_quality_replay_packet_gate".to_string(),
            answer_packet_ref:
                "answer_packet:gemma_qat_e2b_same_fixture_quality_replay_packet_gate".to_string(),
            abstention_ref: "abstention:gemma_qat_e2b_same_fixture_quality_replay_packet_gate"
                .to_string(),
            status: GemmaQatE2bSameFixtureQualityReplayPacketGateStatus::QualityPacketContractOnly,
            next_cursor: GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_NEXT_CURSOR
                .to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaQatE2bSameFixtureQualityReplayPacketGateError> {
        if !self
            .upstream_reconciliation_ref
            .starts_with(UPSTREAM_RECONCILIATION_PREFIX)
            || self.upstream_reconciliation_id
                != GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_ID
        {
            return Err(GemmaQatE2bSameFixtureQualityReplayPacketGateError::BadUpstreamRef);
        }
        validate_exact(
            "upstream_owner_approved_probe_ref",
            &self.upstream_owner_approved_probe_ref,
            GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_UPSTREAM_REF,
        )?;
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
        if self.selected_model_id != GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID
            || self.source_revision != GEMMA_QAT_E2B_SOURCE_REVISION
            || self.required_filename != GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME
            || self.expected_file_size_bytes != GEMMA_QAT_E2B_EXPECTED_FILE_BYTES
            || self.runtime_lane != GemmaFamilyRuntimeLane::GgufLlamaCpp
            || self.command_path != GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH
            || self.fixture_pack_digest != FIXTURE_PACK_DIGEST
            || self.scorer_bundle_digest != SCORER_BUNDLE_DIGEST
        {
            return Err(GemmaQatE2bSameFixtureQualityReplayPacketGateError::BadSelectedLane);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaQatE2bSameFixtureQualityReplayPacketGateStatus::QualityPacketContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaQatE2bSameFixtureQualityReplayPacketGateError::UnsafeState);
        }
        validate_task_family_coverage(&self.task_families)?;
        if !self.upstream_reconciliation_digest_required
            || !self.owner_approval_digest_required
            || !self.owner_manifest_digest_required
            || !self.canonical_path_digest_required
            || !self.model_file_digest_match_required
            || !self.llama_cpp_binary_digest_match_required
            || !self.llama_cpp_version_digest_match_required
            || !self.same_fixture_pack_digest_required
            || !self.held_out_split_bound
            || !self.prompt_context_tool_digests_required
            || !self.redacted_final_output_digest_required
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
        {
            return Err(GemmaQatE2bSameFixtureQualityReplayPacketGateError::ProofBoundaryBroken);
        }
        if self.future_quality_packet_present
            || self.future_quality_packet_bytes_read != 0
            || self.accepted_quality_packet_count != 0
            || self.quality_replay_performed_count != 0
        {
            return Err(
                GemmaQatE2bSameFixtureQualityReplayPacketGateError::QualityPacketActionLeak,
            );
        }
        if self.fixture_payload_bytes_opened != 0
            || self.runtime_artifact_bytes_read != 0
            || self.scorer_executions != 0
            || self.benchmark_runs != 0
            || self.command_armed
            || self.command_executed
            || self.runtime_replay_performed
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.cache_bytes_reused != 0
        {
            return Err(GemmaQatE2bSameFixtureQualityReplayPacketGateError::RuntimeActionLeak);
        }
        if self.raw_prompt_bytes_captured != 0
            || self.raw_context_bytes_captured != 0
            || self.raw_output_bytes_captured != 0
            || self.raw_judge_bytes_captured != 0
        {
            return Err(GemmaQatE2bSameFixtureQualityReplayPacketGateError::PrivacyLeak);
        }
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.hidden_route_authority
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
            return Err(GemmaQatE2bSameFixtureQualityReplayPacketGateError::PromotionClaim);
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
            GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatE2bSameFixtureQualityReplayPacketGateMetrics {
        GemmaQatE2bSameFixtureQualityReplayPacketGateMetrics {
            required_packet_field_count: self.required_packet_fields.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            task_family_count: self.task_families.len() as u64,
            future_quality_packet_present_count: self.future_quality_packet_present as u64,
            future_quality_packet_bytes_read: self.future_quality_packet_bytes_read,
            accepted_quality_packet_count: self.accepted_quality_packet_count,
            quality_replay_performed_count: self.quality_replay_performed_count,
            fixture_payload_bytes_opened: self.fixture_payload_bytes_opened,
            runtime_artifact_bytes_read: self.runtime_artifact_bytes_read,
            scorer_executions: self.scorer_executions,
            benchmark_runs: self.benchmark_runs,
            command_executed_count: self.command_executed as u64,
            runtime_replay_performed_count: self.runtime_replay_performed as u64,
            raw_prompt_bytes_captured: self.raw_prompt_bytes_captured,
            raw_context_bytes_captured: self.raw_context_bytes_captured,
            raw_output_bytes_captured: self.raw_output_bytes_captured,
            raw_judge_bytes_captured: self.raw_judge_bytes_captured,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            cache_bytes_reused: self.cache_bytes_reused,
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

    pub fn packet_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_CURSOR.to_string(),
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
            "gemma-e2b-same-fixture-quality-replay-packet-gate:v1:{}:{}:{}:{}:{}:{}:{}:{}:{}:{}",
            self.upstream_reconciliation_ref,
            self.selected_model_id,
            self.source_revision,
            self.required_filename,
            self.expected_file_size_bytes,
            self.fixture_pack_digest,
            self.scorer_bundle_digest,
            families.join(","),
            fields.join(","),
            policies.join(","),
        )
    }
}

// UAS: uas:gemma-qat-e2b-same-fixture-quality-packet-gate:metrics
// Plane: Verification.
// Residency: zero-action counters for packet, scorer, runtime, and privacy.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bSameFixtureQualityReplayPacketGateMetrics {
    pub required_packet_field_count: u64,
    pub required_rejection_policy_count: u64,
    pub task_family_count: u64,
    pub future_quality_packet_present_count: u64,
    pub future_quality_packet_bytes_read: u64,
    pub accepted_quality_packet_count: u64,
    pub quality_replay_performed_count: u64,
    pub fixture_payload_bytes_opened: u64,
    pub runtime_artifact_bytes_read: u64,
    pub scorer_executions: u64,
    pub benchmark_runs: u64,
    pub command_executed_count: u64,
    pub runtime_replay_performed_count: u64,
    pub raw_prompt_bytes_captured: u64,
    pub raw_context_bytes_captured: u64,
    pub raw_output_bytes_captured: u64,
    pub raw_judge_bytes_captured: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub cache_bytes_reused: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_qat_e2b_same_fixture_quality_replay_packet_fields() -> Vec<String> {
    REQUIRED_PACKET_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_qat_e2b_same_fixture_quality_rejection_policies() -> Vec<String> {
    REQUIRED_REJECTION_POLICIES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-qat-e2b-same-fixture-quality-packet-gate:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatE2bSameFixtureQualityReplayPacketGateError {
    BadUpstreamRef,
    BadSelectedLane,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    TaskFamilyBoundaryBroken,
    ProofBoundaryBroken,
    QualityPacketActionLeak,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaQatE2bSameFixtureQualityReplayPacketGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream reconciliation reference"),
            Self::BadSelectedLane => f.write_str("bad selected E2B quality replay lane"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe quality packet gate state"),
            Self::TaskFamilyBoundaryBroken => f.write_str("task family boundary broken"),
            Self::ProofBoundaryBroken => f.write_str("proof boundary broken"),
            Self::QualityPacketActionLeak => f.write_str("quality packet action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaQatE2bSameFixtureQualityReplayPacketGateError {}

fn validate_task_family_coverage(
    actual: &[GemmaQatQualityTaskFamily],
) -> Result<(), GemmaQatE2bSameFixtureQualityReplayPacketGateError> {
    let actual_set: BTreeSet<GemmaQatQualityTaskFamily> = actual.iter().copied().collect();
    let expected_set: BTreeSet<GemmaQatQualityTaskFamily> =
        GEMMA_QAT_QUALITY_TASK_FAMILIES.iter().copied().collect();
    if actual.len() != GEMMA_QAT_QUALITY_TASK_FAMILIES.len()
        || actual_set.len() != actual.len()
        || actual_set != expected_set
    {
        Err(GemmaQatE2bSameFixtureQualityReplayPacketGateError::TaskFamilyBoundaryBroken)
    } else {
        Ok(())
    }
}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaQatE2bSameFixtureQualityReplayPacketGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaQatE2bSameFixtureQualityReplayPacketGateError::DuplicateOrMissingField(field_name),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaQatE2bSameFixtureQualityReplayPacketGateError::DuplicateOrMissingField(field_name),
        );
    }
    Ok(())
}

fn validate_prefix(
    field_name: &'static str,
    actual: &str,
    expected_prefix: &str,
) -> Result<(), GemmaQatE2bSameFixtureQualityReplayPacketGateError> {
    if actual.starts_with(expected_prefix) {
        Ok(())
    } else {
        Err(GemmaQatE2bSameFixtureQualityReplayPacketGateError::BadField(field_name))
    }
}

fn validate_exact(
    field_name: &'static str,
    actual: &str,
    expected: &str,
) -> Result<(), GemmaQatE2bSameFixtureQualityReplayPacketGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaQatE2bSameFixtureQualityReplayPacketGateError::BadField(field_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_405_600_000;

    #[test]
    fn canonical_packet_gate_validates_zero_actions() {
        let gate = GemmaQatE2bSameFixtureQualityReplayPacketGate::canonical(
            GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_UPSTREAM_REF,
        );
        gate.validate()
            .expect("canonical quality gate should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_packet_field_count, 35);
        assert_eq!(metrics.required_rejection_policy_count, 48);
        assert_eq!(metrics.task_family_count, 7);
        assert_eq!(metrics.future_quality_packet_bytes_read, 0);
        assert_eq!(metrics.quality_replay_performed_count, 0);
        assert_eq!(metrics.scorer_executions, 0);
        assert_eq!(metrics.runtime_replay_performed_count, 0);
        assert_eq!(metrics.raw_prompt_bytes_captured, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn duplicate_required_packet_fields_are_rejected() {
        let mut gate = GemmaQatE2bSameFixtureQualityReplayPacketGate::canonical(
            GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_UPSTREAM_REF,
        );
        gate.required_packet_fields[0] = gate.required_packet_fields[1].clone();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaQatE2bSameFixtureQualityReplayPacketGateError::DuplicateOrMissingField(
                    "required_packet_fields"
                )
            )
        ));
    }

    #[test]
    fn missing_task_family_is_rejected() {
        let mut gate = GemmaQatE2bSameFixtureQualityReplayPacketGate::canonical(
            GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_UPSTREAM_REF,
        );
        gate.task_families.pop();
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bSameFixtureQualityReplayPacketGateError::TaskFamilyBoundaryBroken)
        ));
    }

    #[test]
    fn runtime_or_privacy_actions_are_rejected() {
        let mut gate = GemmaQatE2bSameFixtureQualityReplayPacketGate::canonical(
            GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_UPSTREAM_REF,
        );
        gate.scorer_executions = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bSameFixtureQualityReplayPacketGateError::RuntimeActionLeak)
        ));
        let mut gate = GemmaQatE2bSameFixtureQualityReplayPacketGate::canonical(
            GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_UPSTREAM_REF,
        );
        gate.raw_output_bytes_captured = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bSameFixtureQualityReplayPacketGateError::PrivacyLeak)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaQatE2bSameFixtureQualityReplayPacketGate::canonical(
            GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_UPSTREAM_REF,
        );
        let reversed = GemmaQatE2bSameFixtureQualityReplayPacketGate {
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
        reversed.validate().expect("reversed sets remain canonical");
        assert_eq!(
            gate.packet_gate_address(CREATED_AT_MS),
            reversed.packet_gate_address(CREATED_AT_MS)
        );
    }
}
