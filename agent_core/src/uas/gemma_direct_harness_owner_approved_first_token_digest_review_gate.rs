//! Gemma direct harness owner-approved first-token digest review gate.
//!
//! This primitive consumes the redacted dry-run receipt gate and freezes the
//! digest-review contract for a future first-token observation. It is
//! metadata-only: no receipt is read, no token is observed, no raw token text is
//! retained, no command runs, and no route or quality claim promotes.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_ID,
};

pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_FIRST_TOKEN_DIGEST_REVIEW_GATE_ID: &str =
    "F-GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_FIRST_TOKEN_DIGEST_REVIEW_GATE_CURSOR: &str =
    "gemma_direct_harness_owner_approved_first_token_digest_review_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_FIRST_TOKEN_DIGEST_REVIEW_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_same_fixture_quality_packet_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_FIRST_TOKEN_DIGEST_REVIEW_GATE_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate/result.json#F-GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate";

const UPSTREAM_REDACTED_RECEIPT_PREFIX: &str =
    "artifact:falsifiers/gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_direct_harness_owner_approved_first_token_digest_review_gate/";
const REVIEW_CARD_ID: &str =
    "gemma-direct-harness-owner-approved-first-token-digest-review-gate-v1";
const FUTURE_REVIEW_NAME: &str = "owner-approved-gemma-direct-harness-first-token-digest-review-v1";
const MAX_METADATA_BYTES: u64 = 220 * 1024;

const REQUIRED_REVIEW_FIELDS: &[&str] = &[
    "upstream_redacted_receipt_artifact_digest",
    "review_schema_version",
    "owner_approval_digest",
    "redacted_receipt_digest",
    "command_envelope_digest",
    "model_identity_digest",
    "llama_cli_identity_digest",
    "prompt_digest",
    "first_token_digest",
    "first_token_digest_algorithm",
    "tokenizer_identity_digest",
    "chat_template_digest",
    "stdout_digest",
    "stderr_digest",
    "exit_status_digest",
    "memory_sample_digest",
    "timing_sample_digest",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "reviewer_visible_summary_digest",
    "no_raw_token_digest",
    "no_quality_or_route_claim_digest",
];

const REQUIRED_ABORT_CONDITIONS: &[&str] = &[
    "missing_upstream_redacted_receipt",
    "missing_owner_approval",
    "missing_redacted_receipt_digest",
    "missing_command_envelope_digest",
    "missing_model_identity_digest",
    "missing_llama_cli_identity_digest",
    "missing_prompt_digest",
    "missing_first_token_digest",
    "missing_digest_algorithm",
    "missing_tokenizer_identity_digest",
    "missing_chat_template_digest",
    "missing_stdout_digest",
    "missing_stderr_digest",
    "missing_exit_status_digest",
    "missing_memory_sample",
    "missing_timing_sample",
    "missing_rollback",
    "missing_run_event_log",
    "missing_answer_packet",
    "missing_abstention",
    "missing_visible_summary",
    "missing_no_raw_token",
    "missing_no_quality_or_route_claim",
    "receipt_read",
    "review_written",
    "raw_prompt_retained",
    "raw_output_retained",
    "raw_stdout_retained",
    "raw_stderr_retained",
    "raw_token_retained",
    "token_observed_live",
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
    "l2_l3_t4_claim",
    "live_gemma_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-direct-harness-owner-approved-first-token-digest-review-gate:status
// Plane: Verification.
// Residency: metadata-only digest review contract; no token bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateStatus {
    FirstTokenDigestReviewContractOnly,
}

// UAS: uas:gemma-direct-harness-owner-approved-first-token-digest-review-gate:spec
// Plane: Verification.
// Residency: future digest review only; no live token observation.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGate {
    pub upstream_redacted_receipt_ref: String,
    pub upstream_redacted_receipt_id: String,
    pub artifact_root_prefix: String,
    pub review_card_id: String,
    pub future_review_name: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_review_fields: Vec<String>,
    pub required_abort_conditions: Vec<String>,
    pub owner_and_identity_digests_required: bool,
    pub prompt_and_token_digests_required: bool,
    pub tokenizer_and_template_digests_required: bool,
    pub stdio_exit_memory_timing_digests_required: bool,
    pub rollback_log_packet_abstention_required: bool,
    pub visible_summary_required: bool,
    pub no_raw_token_bound: bool,
    pub no_quality_or_route_claim_bound: bool,
    pub future_review_written_count: u64,
    pub future_review_bytes_written: u64,
    pub future_receipt_bytes_read: u64,
    pub command_armed: bool,
    pub command_executed: bool,
    pub process_spawned: bool,
    pub token_observed_live: bool,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_prompt_bytes: u64,
    pub raw_output_bytes: u64,
    pub raw_stdout_bytes: u64,
    pub raw_stderr_bytes: u64,
    pub raw_token_bytes: u64,
    pub runtime_router_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub settings_or_default_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub quality_claimed: bool,
    pub mas_promoted: bool,
    pub l2_capability_effect: bool,
    pub l3_wrv_effect: bool,
    pub t4_build_green_effect: bool,
    pub live_gemma_default_claim: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub metadata_bytes: u64,
    pub status: GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateStatus,
    pub next_cursor: String,
}

impl GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGate {
    pub fn canonical() -> Self {
        Self {
            upstream_redacted_receipt_ref:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_FIRST_TOKEN_DIGEST_REVIEW_GATE_UPSTREAM_REF
                    .to_string(),
            upstream_redacted_receipt_id:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_ID.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            review_card_id: REVIEW_CARD_ID.to_string(),
            future_review_name: FUTURE_REVIEW_NAME.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_review_fields: REQUIRED_REVIEW_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_abort_conditions: REQUIRED_ABORT_CONDITIONS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            owner_and_identity_digests_required: true,
            prompt_and_token_digests_required: true,
            tokenizer_and_template_digests_required: true,
            stdio_exit_memory_timing_digests_required: true,
            rollback_log_packet_abstention_required: true,
            visible_summary_required: true,
            no_raw_token_bound: true,
            no_quality_or_route_claim_bound: true,
            future_review_written_count: 0,
            future_review_bytes_written: 0,
            future_receipt_bytes_read: 0,
            command_armed: false,
            command_executed: false,
            process_spawned: false,
            token_observed_live: false,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            raw_prompt_bytes: 0,
            raw_output_bytes: 0,
            raw_stdout_bytes: 0,
            raw_stderr_bytes: 0,
            raw_token_bytes: 0,
            runtime_router_mutation_allowed: false,
            system_g_mutation_allowed: false,
            settings_or_default_mutation_allowed: false,
            hidden_route_authority: false,
            hidden_eidos_authority: false,
            hidden_lattice_authority: false,
            hidden_patternboost_authority: false,
            hidden_cloud_fallback: false,
            quality_claimed: false,
            mas_promoted: false,
            l2_capability_effect: false,
            l3_wrv_effect: false,
            t4_build_green_effect: false,
            live_gemma_default_claim: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            metadata_bytes: 184_000,
            status:
                GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateStatus::FirstTokenDigestReviewContractOnly,
            next_cursor:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_FIRST_TOKEN_DIGEST_REVIEW_GATE_NEXT_CURSOR
                    .to_string(),
        }
    }

    pub fn validate(
        &self,
    ) -> Result<(), GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError> {
        if !self
            .upstream_redacted_receipt_ref
            .starts_with(UPSTREAM_REDACTED_RECEIPT_PREFIX)
            || self.upstream_redacted_receipt_id
                != GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_ID
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::BadUpstreamRef,
            );
        }
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("review_card_id", &self.review_card_id, REVIEW_CARD_ID)?;
        validate_exact(
            "future_review_name",
            &self.future_review_name,
            FUTURE_REVIEW_NAME,
        )?;
        validate_unique_exact_set(
            "required_review_fields",
            &self.required_review_fields,
            REQUIRED_REVIEW_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_abort_conditions",
            &self.required_abort_conditions,
            REQUIRED_ABORT_CONDITIONS,
        )?;
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateStatus::FirstTokenDigestReviewContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::UnsafeState,
            );
        }
        if !self.owner_and_identity_digests_required
            || !self.prompt_and_token_digests_required
            || !self.tokenizer_and_template_digests_required
            || !self.stdio_exit_memory_timing_digests_required
            || !self.rollback_log_packet_abstention_required
            || !self.visible_summary_required
            || !self.no_raw_token_bound
            || !self.no_quality_or_route_claim_bound
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::ProofBoundaryBroken,
            );
        }
        if self.future_review_written_count != 0
            || self.future_review_bytes_written != 0
            || self.future_receipt_bytes_read != 0
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::ReviewActionLeak,
            );
        }
        if self.command_armed
            || self.command_executed
            || self.process_spawned
            || self.token_observed_live
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::RuntimeActionLeak,
            );
        }
        if self.raw_prompt_bytes != 0
            || self.raw_output_bytes != 0
            || self.raw_stdout_bytes != 0
            || self.raw_stderr_bytes != 0
            || self.raw_token_bytes != 0
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::PrivacyLeak,
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
            || self.mas_promoted
            || self.l2_capability_effect
            || self.l3_wrv_effect
            || self.t4_build_green_effect
            || self.live_gemma_default_claim
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::PromotionClaim,
            );
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_DIRECT_HARNESS_OWNER_APPROVED_FIRST_TOKEN_DIGEST_REVIEW_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateMetrics {
        GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateMetrics {
            required_review_field_count: self.required_review_fields.len() as u64,
            required_abort_condition_count: self.required_abort_conditions.len() as u64,
            future_review_written_count: self.future_review_written_count,
            future_review_bytes_written: self.future_review_bytes_written,
            future_receipt_bytes_read: self.future_receipt_bytes_read,
            command_armed_count: self.command_armed as u64,
            command_executed_count: self.command_executed as u64,
            process_spawned_count: self.process_spawned as u64,
            token_observed_live_count: self.token_observed_live as u64,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            raw_prompt_bytes: self.raw_prompt_bytes,
            raw_output_bytes: self.raw_output_bytes,
            raw_stdout_bytes: self.raw_stdout_bytes,
            raw_stderr_bytes: self.raw_stderr_bytes,
            raw_token_bytes: self.raw_token_bytes,
            mutation_count: (self.runtime_router_mutation_allowed
                || self.system_g_mutation_allowed
                || self.settings_or_default_mutation_allowed) as u64,
            hidden_authority_count: (self.hidden_route_authority
                || self.hidden_eidos_authority
                || self.hidden_lattice_authority
                || self.hidden_patternboost_authority
                || self.hidden_cloud_fallback) as u64,
            promotion_claim_count: (self.quality_claimed
                || self.mas_promoted
                || self.l2_capability_effect
                || self.l3_wrv_effect
                || self.t4_build_green_effect
                || self.live_gemma_default_claim
                || self.live_dense_70b_claim
                || self.ssd_as_ram_claim) as u64,
        }
    }

    pub fn first_token_review_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_FIRST_TOKEN_DIGEST_REVIEW_GATE_CURSOR
                    .to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_review_fields.clone();
        fields.sort();
        let mut aborts = self.required_abort_conditions.clone();
        aborts.sort();
        format!(
            "gemma-direct-harness-owner-approved-first-token-digest-review-gate:v1:{}:{}:{}:{}:{}",
            self.upstream_redacted_receipt_ref,
            self.upstream_redacted_receipt_id,
            self.future_review_name,
            fields.join(","),
            aborts.join(","),
        )
    }
}

// UAS: uas:gemma-direct-harness-owner-approved-first-token-digest-review-gate:metrics
// Plane: Verification.
// Residency: zero-action first-token review counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateMetrics {
    pub required_review_field_count: u64,
    pub required_abort_condition_count: u64,
    pub future_review_written_count: u64,
    pub future_review_bytes_written: u64,
    pub future_receipt_bytes_read: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub process_spawned_count: u64,
    pub token_observed_live_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_prompt_bytes: u64,
    pub raw_output_bytes: u64,
    pub raw_stdout_bytes: u64,
    pub raw_stderr_bytes: u64,
    pub raw_token_bytes: u64,
    pub mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_direct_harness_owner_approved_first_token_review_fields() -> Vec<String> {
    REQUIRED_REVIEW_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_direct_harness_owner_approved_first_token_review_abort_conditions(
) -> Vec<String> {
    REQUIRED_ABORT_CONDITIONS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-direct-harness-owner-approved-first-token-digest-review-gate:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError {
    BadUpstreamRef,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    ReviewActionLeak,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream redacted receipt reference"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe first-token digest review gate state"),
            Self::ProofBoundaryBroken => f.write_str("first-token review proof boundary broken"),
            Self::ReviewActionLeak => f.write_str("review action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::DuplicateOrMissingField(
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
) -> Result<(), GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::BadField(field_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_754_400_000;

    #[test]
    fn canonical_first_token_review_gate_validates_zero_actions() {
        let gate = GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGate::canonical();
        gate.validate()
            .expect("canonical first-token digest review gate should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_review_field_count, 24);
        assert_eq!(metrics.required_abort_condition_count, 46);
        assert_eq!(metrics.future_review_bytes_written, 0);
        assert_eq!(metrics.future_receipt_bytes_read, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.process_spawned_count, 0);
        assert_eq!(metrics.token_observed_live_count, 0);
        assert_eq!(metrics.raw_token_bytes, 0);
        assert_eq!(metrics.mutation_count, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn duplicate_review_fields_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGate::canonical();
        gate.required_review_fields[0] = gate.required_review_fields[1].clone();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::DuplicateOrMissingField(
                    "required_review_fields"
                )
            )
        ));
    }

    #[test]
    fn review_or_runtime_actions_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGate::canonical();
        gate.future_receipt_bytes_read = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::ReviewActionLeak)
        ));
        let mut gate = GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGate::canonical();
        gate.token_observed_live = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::RuntimeActionLeak)
        ));
    }

    #[test]
    fn raw_token_or_route_claims_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGate::canonical();
        gate.raw_token_bytes = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::PrivacyLeak)
        ));
        let mut gate = GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGate::canonical();
        gate.quality_claimed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGateError::PromotionClaim)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGate::canonical();
        let reversed = GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGate {
            required_review_fields: gate.required_review_fields.iter().cloned().rev().collect(),
            required_abort_conditions: gate
                .required_abort_conditions
                .iter()
                .cloned()
                .rev()
                .collect(),
            ..gate.clone()
        };
        assert_eq!(
            gate.first_token_review_gate_address(CREATED_AT_MS),
            reversed.first_token_review_gate_address(CREATED_AT_MS)
        );
    }
}
