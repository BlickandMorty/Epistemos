use super::{
    canonical_crash_safe_command_envelope_cards, expected_owner_path_manifest_model_ids,
    CompressedModelPromotionTier, CrashSafeCommandEnvelopeCard, CrashSafeCommandEnvelopeState,
    CrashSafeCommandSurface, ProStatus, ProductBuild, UasAddress, UasKind,
};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::str::FromStr;
use thiserror::Error;

pub const EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_ID: &str =
    "F-ExoticQuantOwnerApprovedDryRunTranscriptPreflightGate";
pub const EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_CURSOR: &str =
    "exotic_quant_owner_approved_dry_run_transcript_preflight_gate";
pub const EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_NEXT_CURSOR: &str =
    "exotic_quant_redacted_first_token_probe_preflight_gate";
pub const EXOTIC_QUANT_COMMAND_ENVELOPE_UPSTREAM_REF: &str = "artifact:falsifiers/exotic_quant_crash_safe_command_envelope_preflight_gate/result.json#F-ExoticQuantCrashSafeCommandEnvelopePreflightGate";
pub const EXOTIC_QUANT_BYTE_ENVELOPE_UPSTREAM_REF: &str = "artifact:falsifiers/exotic_quant_owner_path_byte_envelope_preflight_gate/result.json#F-ExoticQuantOwnerPathByteEnvelopePreflightGate";
pub const OWNER_APPROVED_DRY_RUN_TRANSCRIPT_METADATA_BUDGET_BYTES: u64 = 96 * 1024;
pub const OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PHASE_COUNT: usize = 13;

const REQUIRED_TRANSCRIPT_PHASES: [&str; OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PHASE_COUNT] = [
    "owner_approval",
    "scope_rex_admission",
    "serialized_executor",
    "synthetic_prompt",
    "prompt_redaction",
    "model_path_status",
    "stdout_stderr_redaction",
    "credential_redaction",
    "memory_sampling",
    "timeout",
    "cancellation_teardown",
    "rollback",
    "run_event_log_answer_packet",
];

// UAS: uas:exotic-quant-dry-run-transcript:surface
// Plane: Controller
// Residency: transcript surface metadata only; no process or native loader is started.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OwnerApprovedDryRunTranscriptSurface {
    LlamaCppProcessDryRun,
    TransformersPythonQuarantineDryRun,
    ServerOnlyTranscriptDenied,
}

// UAS: uas:exotic-quant-dry-run-transcript:state
// Plane: Verification
// Residency: fail-closed transcript preflight state before any first token.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OwnerApprovedDryRunTranscriptState {
    MacCandidateOwnerApprovalPendingTranscriptPreflight,
    ServerOnlyTranscriptDenied,
}

// UAS: uas:exotic-quant-dry-run-transcript:policy
// Plane: Controller + Verification
// Residency: dry-run safety policy only; owner approval and runtime bytes stay absent.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerApprovedDryRunTranscriptPolicy {
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub owner_approval_signature_present: bool,
    pub scope_rex_admission_required: bool,
    pub scope_rex_admission_granted: bool,
    pub serialized_executor_bound: bool,
    pub synthetic_non_user_prompt_only: bool,
    pub prompt_redaction_bound: bool,
    pub raw_user_prompt_storage_denied: bool,
    pub command_vector_review_bound: bool,
    pub stdout_stderr_redaction_bound: bool,
    pub stdout_stderr_capture_allowed: bool,
    pub output_byte_limits_bound: bool,
    pub credential_redaction_bound: bool,
    pub memory_sampling_plan_bound: bool,
    pub timeout_bound: bool,
    pub cancellation_bound: bool,
    pub teardown_bound: bool,
    pub rollback_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub token_digest_future_only: bool,
    pub first_token_probe_allowed: bool,
    pub no_command_execution: bool,
    pub no_runtime_bytes: bool,
    pub no_product_promotion: bool,
    pub no_hidden_authority: bool,
}

impl OwnerApprovedDryRunTranscriptPolicy {
    pub fn preflight(owner_approval_required: bool) -> Self {
        Self {
            owner_approval_required,
            owner_approval_granted: false,
            owner_approval_signature_present: false,
            scope_rex_admission_required: owner_approval_required,
            scope_rex_admission_granted: false,
            serialized_executor_bound: true,
            synthetic_non_user_prompt_only: true,
            prompt_redaction_bound: true,
            raw_user_prompt_storage_denied: true,
            command_vector_review_bound: true,
            stdout_stderr_redaction_bound: true,
            stdout_stderr_capture_allowed: false,
            output_byte_limits_bound: true,
            credential_redaction_bound: true,
            memory_sampling_plan_bound: true,
            timeout_bound: true,
            cancellation_bound: true,
            teardown_bound: true,
            rollback_bound: true,
            run_event_log_bound: true,
            answer_packet_bound: true,
            token_digest_future_only: true,
            first_token_probe_allowed: false,
            no_command_execution: true,
            no_runtime_bytes: true,
            no_product_promotion: true,
            no_hidden_authority: true,
        }
    }
}

// UAS: uas:exotic-quant-dry-run-transcript:byte-ledger
// Plane: Verification
// Residency: metadata byte accounting; all runtime, model, token, and provider bytes must be zero.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerApprovedDryRunTranscriptByteLedger {
    pub metadata_bytes_read: u64,
    pub transcript_template_bytes_serialized: u64,
    pub owner_approval_bytes_read: u64,
    pub owner_path_bytes_read: u64,
    pub model_artifact_bytes_read: u64,
    pub runtime_bytes_loaded: u64,
    pub command_execution_count: u32,
    pub stdout_bytes_captured: u64,
    pub stderr_bytes_captured: u64,
    pub token_bytes_captured: u64,
    pub provider_bytes_read: u64,
    pub network_bytes_read: u64,
    pub source_code_bytes_imported: u64,
    pub benchmark_bytes_read: u64,
    pub product_surface_bytes_written: u64,
}

impl OwnerApprovedDryRunTranscriptByteLedger {
    pub fn metadata_only(
        metadata_bytes_read: u64,
        transcript_template_bytes_serialized: u64,
    ) -> Self {
        Self {
            metadata_bytes_read,
            transcript_template_bytes_serialized,
            owner_approval_bytes_read: 0,
            owner_path_bytes_read: 0,
            model_artifact_bytes_read: 0,
            runtime_bytes_loaded: 0,
            command_execution_count: 0,
            stdout_bytes_captured: 0,
            stderr_bytes_captured: 0,
            token_bytes_captured: 0,
            provider_bytes_read: 0,
            network_bytes_read: 0,
            source_code_bytes_imported: 0,
            benchmark_bytes_read: 0,
            product_surface_bytes_written: 0,
        }
    }

    fn validate(&self) -> Result<(), OwnerApprovedDryRunTranscriptPreflightError> {
        if self.metadata_bytes_read == 0 {
            return Err(OwnerApprovedDryRunTranscriptPreflightError::MissingMetadataBytes);
        }
        if self.metadata_bytes_read > OWNER_APPROVED_DRY_RUN_TRANSCRIPT_METADATA_BUDGET_BYTES {
            return Err(
                OwnerApprovedDryRunTranscriptPreflightError::MetadataBudgetExceeded {
                    bytes: self.metadata_bytes_read,
                    budget: OWNER_APPROVED_DRY_RUN_TRANSCRIPT_METADATA_BUDGET_BYTES,
                },
            );
        }
        if self.command_execution_count != 0 {
            return Err(OwnerApprovedDryRunTranscriptPreflightError::CommandExecuted);
        }
        if self.owner_approval_bytes_read != 0
            || self.owner_path_bytes_read != 0
            || self.model_artifact_bytes_read != 0
            || self.runtime_bytes_loaded != 0
            || self.stdout_bytes_captured != 0
            || self.stderr_bytes_captured != 0
            || self.token_bytes_captured != 0
            || self.provider_bytes_read != 0
            || self.network_bytes_read != 0
            || self.source_code_bytes_imported != 0
            || self.benchmark_bytes_read != 0
            || self.product_surface_bytes_written != 0
        {
            return Err(OwnerApprovedDryRunTranscriptPreflightError::LiveBytesObserved);
        }
        Ok(())
    }
}

// UAS: uas:exotic-quant-dry-run-transcript:proof-refs
// Plane: Verification
// Residency: visible proof references before owner-approved runtime probing.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerApprovedDryRunTranscriptProofRefs {
    pub upstream_command_envelope_ref: String,
    pub upstream_byte_envelope_ref: String,
    pub owner_approval_ref: String,
    pub admission_ref: String,
    pub serialized_executor_ref: String,
    pub synthetic_prompt_ref: String,
    pub prompt_redaction_ref: String,
    pub model_path_status_ref: String,
    pub output_capture_ref: String,
    pub credential_redaction_ref: String,
    pub memory_sampling_ref: String,
    pub timeout_ref: String,
    pub cancellation_teardown_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub token_digest_policy_ref: String,
    pub non_promotion_ref: String,
}

impl OwnerApprovedDryRunTranscriptProofRefs {
    fn for_command_card(
        upstream_command_envelope_ref: &str,
        card: &CrashSafeCommandEnvelopeCard,
    ) -> Self {
        let pin = card.source_pin_card_id.as_str();
        Self {
            upstream_command_envelope_ref: upstream_command_envelope_ref.to_string(),
            upstream_byte_envelope_ref: card.proof_refs.upstream_byte_envelope_ref.clone(),
            owner_approval_ref: format!("owner_approval:exotic_quant_dry_run:{pin}"),
            admission_ref: format!("admission:scope_rex:exotic_quant_dry_run:{pin}"),
            serialized_executor_ref: format!("executor:serialized_exotic_quant_dry_run:{pin}"),
            synthetic_prompt_ref: format!("prompt:synthetic_non_user:exotic_quant:{pin}"),
            prompt_redaction_ref: format!("redaction:prompt_stdout_stderr:{pin}"),
            model_path_status_ref: format!("model_path_status:owner_path_unopened:{pin}"),
            output_capture_ref: format!("output_capture:redacted_bounded_disabled:{pin}"),
            credential_redaction_ref: format!("credential_redaction:env_and_args:{pin}"),
            memory_sampling_ref: format!("memory_sampling:before_start_after_abort:{pin}"),
            timeout_ref: format!("timeout:dry_run_seconds_cap:{pin}"),
            cancellation_teardown_ref: format!("teardown:cancel_close_wait_kill_tree:{pin}"),
            rollback_ref: format!("rollback:dry_run_no_mutation:{pin}"),
            run_event_log_ref: format!("run_event_log:dry_run_transcript_planned:{pin}"),
            answer_packet_ref: format!("answer_packet:dry_run_transcript_planned:{pin}"),
            token_digest_policy_ref: format!("token_digest:future_redacted_first_token_only:{pin}"),
            non_promotion_ref: format!("non_promotion:t1_metadata_only:{pin}"),
        }
    }

    fn validate(&self) -> Result<(), OwnerApprovedDryRunTranscriptPreflightError> {
        require_artifact_ref(
            &self.upstream_command_envelope_ref,
            "upstream_command_envelope_ref",
            "exotic_quant_crash_safe_command_envelope_preflight_gate",
        )?;
        require_artifact_ref(
            &self.upstream_byte_envelope_ref,
            "upstream_byte_envelope_ref",
            "exotic_quant_owner_path_byte_envelope_preflight_gate",
        )?;
        for (field, value) in [
            ("owner_approval_ref", self.owner_approval_ref.as_str()),
            ("admission_ref", self.admission_ref.as_str()),
            (
                "serialized_executor_ref",
                self.serialized_executor_ref.as_str(),
            ),
            ("synthetic_prompt_ref", self.synthetic_prompt_ref.as_str()),
            ("prompt_redaction_ref", self.prompt_redaction_ref.as_str()),
            ("model_path_status_ref", self.model_path_status_ref.as_str()),
            ("output_capture_ref", self.output_capture_ref.as_str()),
            (
                "credential_redaction_ref",
                self.credential_redaction_ref.as_str(),
            ),
            ("memory_sampling_ref", self.memory_sampling_ref.as_str()),
            ("timeout_ref", self.timeout_ref.as_str()),
            (
                "cancellation_teardown_ref",
                self.cancellation_teardown_ref.as_str(),
            ),
            ("rollback_ref", self.rollback_ref.as_str()),
            ("run_event_log_ref", self.run_event_log_ref.as_str()),
            ("answer_packet_ref", self.answer_packet_ref.as_str()),
            (
                "token_digest_policy_ref",
                self.token_digest_policy_ref.as_str(),
            ),
            ("non_promotion_ref", self.non_promotion_ref.as_str()),
        ] {
            validate_token(field, value)?;
        }
        Ok(())
    }
}

// UAS: uas:exotic-quant-dry-run-transcript:card
// Plane: Controller + Verification
// Residency: transcript preflight card only; no model path, command, or token is opened.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerApprovedDryRunTranscriptPreflightCard {
    pub gate_id: String,
    pub model_id: String,
    pub source_pin: String,
    pub upstream_command_envelope_card_id: String,
    pub surface: OwnerApprovedDryRunTranscriptSurface,
    pub state: OwnerApprovedDryRunTranscriptState,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub command_envelope_visible: bool,
    pub command_armed: bool,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub dry_run_transcript_template_visible: bool,
    pub dry_run_execution_allowed: bool,
    pub first_token_probe_allowed: bool,
    pub first_token_observed: bool,
    pub model_path_opened: bool,
    pub local_artifact_verified: bool,
    pub runtime_probe_allowed: bool,
    pub runtime_deferred: bool,
    pub server_only_transcript_denied: bool,
    pub phase_refs: Vec<String>,
    pub stdout_byte_limit: u64,
    pub stderr_byte_limit: u64,
    pub token_byte_limit: u64,
    pub policy: OwnerApprovedDryRunTranscriptPolicy,
    pub byte_ledger: OwnerApprovedDryRunTranscriptByteLedger,
    pub proof_refs: OwnerApprovedDryRunTranscriptProofRefs,
    pub hidden_route_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub product_route_green: bool,
    pub l2_capability_green: bool,
    pub l3_wrv_green: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub source_code_imported: bool,
    pub benchmark_claimed_as_fit: bool,
    pub next_cursor: String,
    pub user_visible_summary: String,
}

impl OwnerApprovedDryRunTranscriptPreflightCard {
    fn from_command_card(
        upstream_command_envelope_ref: &str,
        card: &CrashSafeCommandEnvelopeCard,
    ) -> Self {
        let mac_candidate = matches!(
            card.state,
            CrashSafeCommandEnvelopeState::MacCandidateUnarmedOwnerApprovalRequired
        );
        let surface = match card.surface {
            CrashSafeCommandSurface::LlamaCppGgufCli => {
                OwnerApprovedDryRunTranscriptSurface::LlamaCppProcessDryRun
            }
            CrashSafeCommandSurface::TransformersPythonQuarantine => {
                OwnerApprovedDryRunTranscriptSurface::TransformersPythonQuarantineDryRun
            }
            CrashSafeCommandSurface::ServerOnlyDenied => {
                OwnerApprovedDryRunTranscriptSurface::ServerOnlyTranscriptDenied
            }
        };
        let state = if mac_candidate {
            OwnerApprovedDryRunTranscriptState::MacCandidateOwnerApprovalPendingTranscriptPreflight
        } else {
            OwnerApprovedDryRunTranscriptState::ServerOnlyTranscriptDenied
        };
        let proof_refs = OwnerApprovedDryRunTranscriptProofRefs::for_command_card(
            upstream_command_envelope_ref,
            card,
        );
        let phase_refs = REQUIRED_TRANSCRIPT_PHASES
            .iter()
            .map(|phase| format!("transcript_phase:{phase}:{}", card.source_pin_card_id))
            .collect::<Vec<_>>();
        let transcript_bytes = if mac_candidate { 12_288 } else { 2_048 };
        Self {
            gate_id: format!(
                "dry_run_transcript_preflight:{}:{}",
                card.model_id, card.source_pin_card_id
            ),
            model_id: card.model_id.clone(),
            source_pin: card.source_pin_card_id.clone(),
            upstream_command_envelope_card_id: card.gate_id.clone(),
            surface,
            state,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
            command_envelope_visible: card.command_envelope_visible,
            command_armed: card.command_armed,
            owner_approval_required: mac_candidate,
            owner_approval_granted: false,
            dry_run_transcript_template_visible: true,
            dry_run_execution_allowed: false,
            first_token_probe_allowed: false,
            first_token_observed: false,
            model_path_opened: false,
            local_artifact_verified: false,
            runtime_probe_allowed: false,
            runtime_deferred: true,
            server_only_transcript_denied: !mac_candidate,
            phase_refs,
            stdout_byte_limit: 4_096,
            stderr_byte_limit: 4_096,
            token_byte_limit: 0,
            policy: OwnerApprovedDryRunTranscriptPolicy::preflight(mac_candidate),
            byte_ledger: OwnerApprovedDryRunTranscriptByteLedger::metadata_only(
                18_432,
                transcript_bytes,
            ),
            proof_refs,
            hidden_route_authority: false,
            hidden_patternboost_authority: false,
            hidden_lattice_authority: false,
            hidden_eidos_authority: false,
            hidden_cloud_fallback: false,
            product_route_green: false,
            l2_capability_green: false,
            l3_wrv_green: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            source_code_imported: false,
            benchmark_claimed_as_fit: false,
            next_cursor: EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_NEXT_CURSOR
                .to_string(),
            user_visible_summary: format!(
                "Dry-run transcript is only a safety template for {model} from {source}. \
                 It records the required owner approval, SCOPE-Rex admission, serialized executor, \
                 redaction, memory sampling, timeout, cancellation, teardown, rollback, RunEventLog, \
                 and AnswerPacket slots before any first-token probe. No command executes, no model \
                 bytes load, and no product capability promotes.",
                model = card.model_id,
                source = card.source_pin_card_id
            ),
        }
    }

    pub fn validate(&self) -> Result<(), OwnerApprovedDryRunTranscriptPreflightError> {
        validate_token("gate_id", &self.gate_id)?;
        validate_token("model_id", &self.model_id)?;
        validate_token("source_pin", &self.source_pin)?;
        validate_token(
            "upstream_command_envelope_card_id",
            &self.upstream_command_envelope_card_id,
        )?;
        validate_text(
            "user_visible_summary",
            &self.user_visible_summary,
            220,
            1200,
        )?;
        if !expected_owner_path_manifest_model_ids().contains(&self.model_id.as_str()) {
            return Err(
                OwnerApprovedDryRunTranscriptPreflightError::UnexpectedModelId(
                    self.model_id.clone(),
                ),
            );
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.promotion_tier != CompressedModelPromotionTier::T1L1Metadata
        {
            return Err(
                OwnerApprovedDryRunTranscriptPreflightError::WrongPromotionTier {
                    gate_id: self.gate_id.clone(),
                },
            );
        }
        if self.next_cursor
            != EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_NEXT_CURSOR
        {
            return Err(
                OwnerApprovedDryRunTranscriptPreflightError::WrongNextCursor {
                    gate_id: self.gate_id.clone(),
                    next_cursor: self.next_cursor.clone(),
                },
            );
        }
        self.validate_surface_state()?;
        self.validate_policy()?;
        self.validate_phase_refs()?;
        self.byte_ledger.validate()?;
        self.proof_refs.validate()?;
        if !self.command_envelope_visible || self.command_armed {
            return Err(
                OwnerApprovedDryRunTranscriptPreflightError::CommandEnvelopeNotSafe {
                    gate_id: self.gate_id.clone(),
                },
            );
        }
        if !self.dry_run_transcript_template_visible
            || self.dry_run_execution_allowed
            || self.first_token_probe_allowed
            || self.first_token_observed
            || self.model_path_opened
            || self.local_artifact_verified
            || self.runtime_probe_allowed
            || !self.runtime_deferred
        {
            return Err(
                OwnerApprovedDryRunTranscriptPreflightError::RuntimeBoundaryBroken {
                    gate_id: self.gate_id.clone(),
                },
            );
        }
        if self.stdout_byte_limit == 0
            || self.stderr_byte_limit == 0
            || self.stdout_byte_limit > 16_384
            || self.stderr_byte_limit > 16_384
            || self.token_byte_limit != 0
        {
            return Err(
                OwnerApprovedDryRunTranscriptPreflightError::OutputLimitsInvalid {
                    gate_id: self.gate_id.clone(),
                },
            );
        }
        if self.hidden_route_authority
            || self.hidden_patternboost_authority
            || self.hidden_lattice_authority
            || self.hidden_eidos_authority
            || self.hidden_cloud_fallback
            || self.product_route_green
            || self.l2_capability_green
            || self.l3_wrv_green
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
            || self.source_code_imported
            || self.benchmark_claimed_as_fit
        {
            return Err(
                OwnerApprovedDryRunTranscriptPreflightError::FalseClaimOrHiddenAuthority {
                    gate_id: self.gate_id.clone(),
                },
            );
        }
        Ok(())
    }

    fn validate_surface_state(&self) -> Result<(), OwnerApprovedDryRunTranscriptPreflightError> {
        match (self.surface, self.state) {
            (
                OwnerApprovedDryRunTranscriptSurface::LlamaCppProcessDryRun
                | OwnerApprovedDryRunTranscriptSurface::TransformersPythonQuarantineDryRun,
                OwnerApprovedDryRunTranscriptState::MacCandidateOwnerApprovalPendingTranscriptPreflight,
            ) => {
                if !self.owner_approval_required
                    || self.owner_approval_granted
                    || self.server_only_transcript_denied
                {
                    return Err(
                        OwnerApprovedDryRunTranscriptPreflightError::OwnerApprovalBoundaryBroken {
                            gate_id: self.gate_id.clone(),
                        },
                    );
                }
            }
            (
                OwnerApprovedDryRunTranscriptSurface::ServerOnlyTranscriptDenied,
                OwnerApprovedDryRunTranscriptState::ServerOnlyTranscriptDenied,
            ) => {
                if self.owner_approval_required
                    || self.owner_approval_granted
                    || !self.server_only_transcript_denied
                {
                    return Err(
                        OwnerApprovedDryRunTranscriptPreflightError::ServerOnlyBoundaryBroken {
                            gate_id: self.gate_id.clone(),
                        },
                    );
                }
            }
            _ => {
                return Err(OwnerApprovedDryRunTranscriptPreflightError::WrongSurfaceState {
                    gate_id: self.gate_id.clone(),
                });
            }
        }
        Ok(())
    }

    fn validate_policy(&self) -> Result<(), OwnerApprovedDryRunTranscriptPreflightError> {
        if self.policy.owner_approval_required != self.owner_approval_required
            || self.policy.owner_approval_granted
            || self.policy.owner_approval_signature_present
            || self.policy.scope_rex_admission_required != self.owner_approval_required
            || self.policy.scope_rex_admission_granted
            || !self.policy.serialized_executor_bound
            || !self.policy.synthetic_non_user_prompt_only
            || !self.policy.prompt_redaction_bound
            || !self.policy.raw_user_prompt_storage_denied
            || !self.policy.command_vector_review_bound
            || !self.policy.stdout_stderr_redaction_bound
            || self.policy.stdout_stderr_capture_allowed
            || !self.policy.output_byte_limits_bound
            || !self.policy.credential_redaction_bound
            || !self.policy.memory_sampling_plan_bound
            || !self.policy.timeout_bound
            || !self.policy.cancellation_bound
            || !self.policy.teardown_bound
            || !self.policy.rollback_bound
            || !self.policy.run_event_log_bound
            || !self.policy.answer_packet_bound
            || !self.policy.token_digest_future_only
            || self.policy.first_token_probe_allowed
            || !self.policy.no_command_execution
            || !self.policy.no_runtime_bytes
            || !self.policy.no_product_promotion
            || !self.policy.no_hidden_authority
        {
            return Err(OwnerApprovedDryRunTranscriptPreflightError::PolicyBroken {
                gate_id: self.gate_id.clone(),
            });
        }
        Ok(())
    }

    fn validate_phase_refs(&self) -> Result<(), OwnerApprovedDryRunTranscriptPreflightError> {
        if self.phase_refs.len() != OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PHASE_COUNT {
            return Err(
                OwnerApprovedDryRunTranscriptPreflightError::MissingTranscriptPhase {
                    gate_id: self.gate_id.clone(),
                },
            );
        }
        let mut seen = BTreeSet::new();
        for phase_ref in &self.phase_refs {
            validate_token("phase_ref", phase_ref)?;
            if !phase_ref.starts_with("transcript_phase:") || !phase_ref.ends_with(&self.source_pin)
            {
                return Err(
                    OwnerApprovedDryRunTranscriptPreflightError::MissingTranscriptPhase {
                        gate_id: self.gate_id.clone(),
                    },
                );
            }
            if !seen.insert(phase_ref) {
                return Err(
                    OwnerApprovedDryRunTranscriptPreflightError::DuplicateTranscriptPhase {
                        gate_id: self.gate_id.clone(),
                        phase_ref: phase_ref.clone(),
                    },
                );
            }
        }
        for phase in REQUIRED_TRANSCRIPT_PHASES {
            let expected = format!("transcript_phase:{phase}:{}", self.source_pin);
            if !seen.contains(&expected) {
                return Err(
                    OwnerApprovedDryRunTranscriptPreflightError::MissingTranscriptPhase {
                        gate_id: self.gate_id.clone(),
                    },
                );
            }
        }
        Ok(())
    }
}

// UAS: uas:exotic-quant-dry-run-transcript:metrics
// Plane: Verification
// Residency: aggregate proof metrics for metadata-only transcript preflight.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerApprovedDryRunTranscriptPreflightMetrics {
    pub accepted_transcript_card_count: usize,
    pub mac_candidate_owner_approval_pending_count: usize,
    pub server_only_transcript_denied_count: usize,
    pub transcript_phase_total_count: usize,
    pub owner_approval_required_count: usize,
    pub owner_approval_granted_count: usize,
    pub dry_run_execution_allowed_count: usize,
    pub first_token_observed_count: usize,
    pub runtime_probe_allowed_count: usize,
    pub command_execution_count: u32,
    pub runtime_bytes_loaded: u64,
    pub model_artifact_bytes_read: u64,
    pub stdout_bytes_captured: u64,
    pub stderr_bytes_captured: u64,
    pub token_bytes_captured: u64,
    pub product_green_count: usize,
    pub hidden_authority_count: usize,
    pub next_cursor: String,
}

// UAS: uas:exotic-quant-dry-run-transcript:ledger
// Plane: Verification
// Residency: metadata-only ledger for the owner-approved dry-run transcript gate.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerApprovedDryRunTranscriptPreflightLedger {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_command_envelope_ref: String,
    pub upstream_command_envelope_address: UasAddress,
    pub cards: Vec<OwnerApprovedDryRunTranscriptPreflightCard>,
    pub address: UasAddress,
    pub metrics: OwnerApprovedDryRunTranscriptPreflightMetrics,
    pub metadata_only: bool,
    pub runtime_deferred_reason: String,
}

impl OwnerApprovedDryRunTranscriptPreflightLedger {
    pub fn new(
        upstream_command_envelope_ref: &str,
        upstream_command_envelope_address: UasAddress,
        mut cards: Vec<OwnerApprovedDryRunTranscriptPreflightCard>,
    ) -> Result<Self, OwnerApprovedDryRunTranscriptPreflightError> {
        require_artifact_ref(
            upstream_command_envelope_ref,
            "upstream_command_envelope_ref",
            "exotic_quant_crash_safe_command_envelope_preflight_gate",
        )?;
        validate_uas_address(&upstream_command_envelope_address)
            .map_err(|_| OwnerApprovedDryRunTranscriptPreflightError::BadUpstreamAddress)?;
        cards.sort_by(|a, b| a.gate_id.cmp(&b.gate_id));
        if cards.is_empty() {
            return Err(OwnerApprovedDryRunTranscriptPreflightError::EmptyCardSet);
        }
        let mut seen_gate_ids = BTreeSet::new();
        let mut seen_models = BTreeSet::new();
        for card in &cards {
            card.validate()?;
            if !seen_gate_ids.insert(card.gate_id.as_str()) {
                return Err(
                    OwnerApprovedDryRunTranscriptPreflightError::DuplicateGateId(
                        card.gate_id.clone(),
                    ),
                );
            }
            seen_models.insert(card.model_id.as_str());
        }
        for expected in expected_owner_path_manifest_model_ids() {
            if !seen_models.contains(expected) {
                return Err(
                    OwnerApprovedDryRunTranscriptPreflightError::MissingExpectedModel(
                        expected.to_string(),
                    ),
                );
            }
        }
        let metrics = metrics_for_cards(&cards);
        if metrics.accepted_transcript_card_count != cards.len()
            || metrics.mac_candidate_owner_approval_pending_count == 0
            || metrics.server_only_transcript_denied_count == 0
            || metrics.owner_approval_granted_count != 0
            || metrics.dry_run_execution_allowed_count != 0
            || metrics.first_token_observed_count != 0
            || metrics.runtime_probe_allowed_count != 0
            || metrics.command_execution_count != 0
            || metrics.runtime_bytes_loaded != 0
            || metrics.model_artifact_bytes_read != 0
            || metrics.stdout_bytes_captured != 0
            || metrics.stderr_bytes_captured != 0
            || metrics.token_bytes_captured != 0
            || metrics.product_green_count != 0
            || metrics.hidden_authority_count != 0
        {
            return Err(OwnerApprovedDryRunTranscriptPreflightError::MetricsBroken);
        }
        let address = UasAddress::new(
            UasKind::Other(
                EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_ID.to_string(),
            ),
            &ledger_preimage(
                upstream_command_envelope_ref,
                &upstream_command_envelope_address,
                &cards,
                &metrics,
            ),
            1,
        );
        validate_uas_address(&address)
            .map_err(|_| OwnerApprovedDryRunTranscriptPreflightError::BadLedgerAddress)?;
        Ok(Self {
            falsifier_id: EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_ID.to_string(),
            cursor: EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_CURSOR.to_string(),
            next_cursor: EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_NEXT_CURSOR
                .to_string(),
            upstream_command_envelope_ref: upstream_command_envelope_ref.to_string(),
            upstream_command_envelope_address,
            cards,
            address,
            metrics,
            metadata_only: true,
            runtime_deferred_reason: "Owner-approved dry-run transcript is a Pro Gated T1 preflight. It binds approval, redaction, memory sampling, timeout, cancellation, teardown, rollback, RunEventLog, and AnswerPacket slots without executing a command, opening owner paths, loading model bytes, or promoting L2/L3/product capability.".to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), OwnerApprovedDryRunTranscriptPreflightError> {
        if self.falsifier_id != EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_ID
            || self.cursor != EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_CURSOR
            || self.next_cursor
                != EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_NEXT_CURSOR
            || !self.metadata_only
            || self.runtime_deferred_reason.len() < 180
        {
            return Err(OwnerApprovedDryRunTranscriptPreflightError::LedgerHeaderBroken);
        }
        require_artifact_ref(
            &self.upstream_command_envelope_ref,
            "upstream_command_envelope_ref",
            "exotic_quant_crash_safe_command_envelope_preflight_gate",
        )?;
        validate_uas_address(&self.upstream_command_envelope_address)
            .map_err(|_| OwnerApprovedDryRunTranscriptPreflightError::BadUpstreamAddress)?;
        let rebuilt = Self::new(
            &self.upstream_command_envelope_ref,
            self.upstream_command_envelope_address.clone(),
            self.cards.clone(),
        )?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(OwnerApprovedDryRunTranscriptPreflightError::LedgerDigestMismatch);
        }
        Ok(())
    }
}

pub fn canonical_owner_approved_dry_run_transcript_preflight_cards(
    upstream_command_envelope_ref: &str,
    command_cards: &[CrashSafeCommandEnvelopeCard],
) -> Vec<OwnerApprovedDryRunTranscriptPreflightCard> {
    command_cards
        .iter()
        .map(|card| {
            OwnerApprovedDryRunTranscriptPreflightCard::from_command_card(
                upstream_command_envelope_ref,
                card,
            )
        })
        .collect()
}

pub fn canonical_owner_approved_dry_run_transcript_preflight_ledger(
    upstream_command_envelope_address: UasAddress,
) -> Result<OwnerApprovedDryRunTranscriptPreflightLedger, OwnerApprovedDryRunTranscriptPreflightError>
{
    let command_cards =
        canonical_crash_safe_command_envelope_cards(EXOTIC_QUANT_BYTE_ENVELOPE_UPSTREAM_REF);
    let cards = canonical_owner_approved_dry_run_transcript_preflight_cards(
        EXOTIC_QUANT_COMMAND_ENVELOPE_UPSTREAM_REF,
        &command_cards,
    );
    OwnerApprovedDryRunTranscriptPreflightLedger::new(
        EXOTIC_QUANT_COMMAND_ENVELOPE_UPSTREAM_REF,
        upstream_command_envelope_address,
        cards,
    )
}

fn metrics_for_cards(
    cards: &[OwnerApprovedDryRunTranscriptPreflightCard],
) -> OwnerApprovedDryRunTranscriptPreflightMetrics {
    OwnerApprovedDryRunTranscriptPreflightMetrics {
        accepted_transcript_card_count: cards.len(),
        mac_candidate_owner_approval_pending_count: cards
            .iter()
            .filter(|card| {
                card.state
                    == OwnerApprovedDryRunTranscriptState::MacCandidateOwnerApprovalPendingTranscriptPreflight
            })
            .count(),
        server_only_transcript_denied_count: cards
            .iter()
            .filter(|card| card.state == OwnerApprovedDryRunTranscriptState::ServerOnlyTranscriptDenied)
            .count(),
        transcript_phase_total_count: cards.iter().map(|card| card.phase_refs.len()).sum(),
        owner_approval_required_count: cards
            .iter()
            .filter(|card| card.owner_approval_required)
            .count(),
        owner_approval_granted_count: cards
            .iter()
            .filter(|card| card.owner_approval_granted)
            .count(),
        dry_run_execution_allowed_count: cards
            .iter()
            .filter(|card| card.dry_run_execution_allowed)
            .count(),
        first_token_observed_count: cards
            .iter()
            .filter(|card| card.first_token_observed)
            .count(),
        runtime_probe_allowed_count: cards
            .iter()
            .filter(|card| card.runtime_probe_allowed)
            .count(),
        command_execution_count: cards
            .iter()
            .map(|card| card.byte_ledger.command_execution_count)
            .sum(),
        runtime_bytes_loaded: cards
            .iter()
            .map(|card| card.byte_ledger.runtime_bytes_loaded)
            .sum(),
        model_artifact_bytes_read: cards
            .iter()
            .map(|card| card.byte_ledger.model_artifact_bytes_read)
            .sum(),
        stdout_bytes_captured: cards
            .iter()
            .map(|card| card.byte_ledger.stdout_bytes_captured)
            .sum(),
        stderr_bytes_captured: cards
            .iter()
            .map(|card| card.byte_ledger.stderr_bytes_captured)
            .sum(),
        token_bytes_captured: cards
            .iter()
            .map(|card| card.byte_ledger.token_bytes_captured)
            .sum(),
        product_green_count: cards
            .iter()
            .filter(|card| card.product_route_green || card.l2_capability_green || card.l3_wrv_green)
            .count(),
        hidden_authority_count: cards
            .iter()
            .filter(|card| {
                card.hidden_route_authority
                    || card.hidden_patternboost_authority
                    || card.hidden_lattice_authority
                    || card.hidden_eidos_authority
                    || card.hidden_cloud_fallback
            })
            .count(),
        next_cursor: EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_NEXT_CURSOR
            .to_string(),
    }
}

fn ledger_preimage(
    upstream_command_envelope_ref: &str,
    upstream_command_envelope_address: &UasAddress,
    cards: &[OwnerApprovedDryRunTranscriptPreflightCard],
    metrics: &OwnerApprovedDryRunTranscriptPreflightMetrics,
) -> Vec<u8> {
    let mut preimage = Vec::with_capacity(12_288);
    preimage.extend_from_slice(
        EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_ID.as_bytes(),
    );
    preimage.extend_from_slice(
        EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_CURSOR.as_bytes(),
    );
    preimage.extend_from_slice(
        EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_NEXT_CURSOR.as_bytes(),
    );
    preimage.extend_from_slice(upstream_command_envelope_ref.as_bytes());
    preimage.extend_from_slice(upstream_command_envelope_address.to_string().as_bytes());
    for card in cards {
        preimage.extend_from_slice(card.gate_id.as_bytes());
        preimage.extend_from_slice(card.model_id.as_bytes());
        preimage.extend_from_slice(card.source_pin.as_bytes());
        preimage.extend_from_slice(card.upstream_command_envelope_card_id.as_bytes());
        preimage.extend_from_slice(format!("{:?}", card.surface).as_bytes());
        preimage.extend_from_slice(format!("{:?}", card.state).as_bytes());
        for phase_ref in &card.phase_refs {
            preimage.extend_from_slice(phase_ref.as_bytes());
        }
        preimage.extend_from_slice(card.proof_refs.owner_approval_ref.as_bytes());
        preimage.extend_from_slice(card.proof_refs.admission_ref.as_bytes());
        preimage.extend_from_slice(card.proof_refs.run_event_log_ref.as_bytes());
        preimage.extend_from_slice(card.proof_refs.answer_packet_ref.as_bytes());
        preimage.extend_from_slice(card.next_cursor.as_bytes());
    }
    preimage.extend_from_slice(format!("{metrics:?}").as_bytes());
    preimage
}

fn require_artifact_ref(
    value: &str,
    field: &'static str,
    expected_slug: &'static str,
) -> Result<(), OwnerApprovedDryRunTranscriptPreflightError> {
    validate_token(field, value)?;
    if !value.starts_with("artifact:falsifiers/")
        || !value.contains(expected_slug)
        || !value.contains("/result.json#")
    {
        return Err(
            OwnerApprovedDryRunTranscriptPreflightError::BadArtifactRef {
                field,
                value: value.to_string(),
            },
        );
    }
    Ok(())
}

fn validate_uas_address(
    address: &UasAddress,
) -> Result<(), OwnerApprovedDryRunTranscriptPreflightError> {
    let rendered = address.to_string();
    let reparsed = UasAddress::from_str(&rendered).map_err(|_| {
        OwnerApprovedDryRunTranscriptPreflightError::BadAddressWireFormat(rendered.clone())
    })?;
    if &reparsed != address {
        return Err(OwnerApprovedDryRunTranscriptPreflightError::BadAddressWireFormat(rendered));
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), OwnerApprovedDryRunTranscriptPreflightError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(OwnerApprovedDryRunTranscriptPreflightError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(
    field: &'static str,
    value: &str,
    min_len: usize,
    max_len: usize,
) -> Result<(), OwnerApprovedDryRunTranscriptPreflightError> {
    if value.trim().len() < min_len
        || value.len() > max_len
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(OwnerApprovedDryRunTranscriptPreflightError::InvalidText {
            field,
            len: value.len(),
        });
    }
    Ok(())
}

// UAS: uas:exotic-quant-dry-run-transcript:error
// Plane: Verification
// Residency: fail-closed validation error surface; no runtime side effects.
#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum OwnerApprovedDryRunTranscriptPreflightError {
    #[error("invalid token for {field}: {value}")]
    InvalidToken { field: &'static str, value: String },
    #[error("invalid text for {field}; len={len}")]
    InvalidText { field: &'static str, len: usize },
    #[error("bad artifact ref for {field}: {value}")]
    BadArtifactRef { field: &'static str, value: String },
    #[error("bad upstream address")]
    BadUpstreamAddress,
    #[error("bad ledger address")]
    BadLedgerAddress,
    #[error("bad address wire format: {0}")]
    BadAddressWireFormat(String),
    #[error("empty card set")]
    EmptyCardSet,
    #[error("duplicate gate id: {0}")]
    DuplicateGateId(String),
    #[error("unexpected model id: {0}")]
    UnexpectedModelId(String),
    #[error("missing expected model: {0}")]
    MissingExpectedModel(String),
    #[error("wrong promotion tier for {gate_id}")]
    WrongPromotionTier { gate_id: String },
    #[error("wrong next cursor for {gate_id}: {next_cursor}")]
    WrongNextCursor {
        gate_id: String,
        next_cursor: String,
    },
    #[error("wrong surface/state for {gate_id}")]
    WrongSurfaceState { gate_id: String },
    #[error("owner approval boundary broken for {gate_id}")]
    OwnerApprovalBoundaryBroken { gate_id: String },
    #[error("server-only boundary broken for {gate_id}")]
    ServerOnlyBoundaryBroken { gate_id: String },
    #[error("policy broken for {gate_id}")]
    PolicyBroken { gate_id: String },
    #[error("missing transcript phase for {gate_id}")]
    MissingTranscriptPhase { gate_id: String },
    #[error("duplicate transcript phase for {gate_id}: {phase_ref}")]
    DuplicateTranscriptPhase { gate_id: String, phase_ref: String },
    #[error("missing metadata bytes")]
    MissingMetadataBytes,
    #[error("metadata budget exceeded: {bytes}>{budget}")]
    MetadataBudgetExceeded { bytes: u64, budget: u64 },
    #[error("command executed")]
    CommandExecuted,
    #[error("live bytes observed")]
    LiveBytesObserved,
    #[error("command envelope unsafe for {gate_id}")]
    CommandEnvelopeNotSafe { gate_id: String },
    #[error("runtime boundary broken for {gate_id}")]
    RuntimeBoundaryBroken { gate_id: String },
    #[error("output limits invalid for {gate_id}")]
    OutputLimitsInvalid { gate_id: String },
    #[error("false claim or hidden authority for {gate_id}")]
    FalseClaimOrHiddenAuthority { gate_id: String },
    #[error("metrics broken")]
    MetricsBroken,
    #[error("ledger header broken")]
    LedgerHeaderBroken,
    #[error("ledger digest mismatch")]
    LedgerDigestMismatch,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::UasKind;

    fn test_upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("F-ExoticQuantCrashSafeCommandEnvelopePreflightGate".to_string()),
            b"stable command envelope test address",
            1,
        )
    }

    fn canonical_ledger() -> OwnerApprovedDryRunTranscriptPreflightLedger {
        canonical_owner_approved_dry_run_transcript_preflight_ledger(test_upstream_address())
            .expect("canonical dry-run transcript ledger should validate")
    }

    #[test]
    fn accepts_canonical_owner_approved_dry_run_transcript_preflight_without_execution() {
        let ledger = canonical_ledger();
        ledger.validate().expect("canonical ledger validates");

        assert_eq!(
            ledger.cursor,
            EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_CURSOR
        );
        assert_eq!(
            ledger.next_cursor,
            EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_NEXT_CURSOR
        );
        assert!(ledger.metadata_only);
        assert!(ledger.metrics.owner_approval_required_count > 0);
        assert_eq!(ledger.metrics.owner_approval_granted_count, 0);
        assert_eq!(ledger.metrics.command_execution_count, 0);
        assert_eq!(ledger.metrics.runtime_bytes_loaded, 0);
        assert_eq!(ledger.metrics.first_token_observed_count, 0);
    }

    #[test]
    fn rejects_owner_approval_or_command_execution_leaks() {
        let mut ledger = canonical_ledger();
        let card = ledger
            .cards
            .iter_mut()
            .find(|card| card.owner_approval_required)
            .expect("mac candidate card exists");
        card.owner_approval_granted = true;
        card.policy.owner_approval_granted = true;
        assert!(matches!(
            OwnerApprovedDryRunTranscriptPreflightLedger::new(
                &ledger.upstream_command_envelope_ref,
                ledger.upstream_command_envelope_address.clone(),
                ledger.cards.clone(),
            ),
            Err(OwnerApprovedDryRunTranscriptPreflightError::OwnerApprovalBoundaryBroken { .. })
                | Err(OwnerApprovedDryRunTranscriptPreflightError::PolicyBroken { .. })
        ));

        let mut ledger = canonical_ledger();
        ledger.cards[0].byte_ledger.command_execution_count = 1;
        assert_eq!(
            OwnerApprovedDryRunTranscriptPreflightLedger::new(
                &ledger.upstream_command_envelope_ref,
                ledger.upstream_command_envelope_address,
                ledger.cards,
            ),
            Err(OwnerApprovedDryRunTranscriptPreflightError::CommandExecuted)
        );
    }

    #[test]
    fn rejects_prompt_output_and_first_token_boundary_breaks() {
        let mut ledger = canonical_ledger();
        ledger.cards[0].policy.raw_user_prompt_storage_denied = false;
        assert!(matches!(
            OwnerApprovedDryRunTranscriptPreflightLedger::new(
                &ledger.upstream_command_envelope_ref,
                ledger.upstream_command_envelope_address.clone(),
                ledger.cards.clone(),
            ),
            Err(OwnerApprovedDryRunTranscriptPreflightError::PolicyBroken { .. })
        ));

        let mut ledger = canonical_ledger();
        ledger.cards[0].first_token_observed = true;
        ledger.cards[0].byte_ledger.token_bytes_captured = 8;
        assert!(matches!(
            OwnerApprovedDryRunTranscriptPreflightLedger::new(
                &ledger.upstream_command_envelope_ref,
                ledger.upstream_command_envelope_address,
                ledger.cards,
            ),
            Err(OwnerApprovedDryRunTranscriptPreflightError::LiveBytesObserved)
                | Err(OwnerApprovedDryRunTranscriptPreflightError::RuntimeBoundaryBroken { .. })
        ));
    }

    #[test]
    fn produces_stable_digest_for_sorted_cards() {
        let ledger = canonical_ledger();
        let mut reversed = ledger.cards.clone();
        reversed.reverse();
        let rebuilt = OwnerApprovedDryRunTranscriptPreflightLedger::new(
            &ledger.upstream_command_envelope_ref,
            ledger.upstream_command_envelope_address.clone(),
            reversed,
        )
        .expect("reversed cards sort into same ledger");
        assert_eq!(ledger.address, rebuilt.address);
        assert_eq!(ledger.metrics, rebuilt.metrics);
    }
}
