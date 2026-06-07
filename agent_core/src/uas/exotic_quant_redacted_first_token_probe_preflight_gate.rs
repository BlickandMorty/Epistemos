use super::{
    canonical_crash_safe_command_envelope_cards,
    canonical_owner_approved_dry_run_transcript_preflight_cards,
    expected_owner_path_manifest_model_ids, CompressedModelPromotionTier,
    OwnerApprovedDryRunTranscriptPreflightCard, OwnerApprovedDryRunTranscriptState,
    OwnerApprovedDryRunTranscriptSurface, ProStatus, ProductBuild, UasAddress, UasKind,
    EXOTIC_QUANT_BYTE_ENVELOPE_UPSTREAM_REF, EXOTIC_QUANT_COMMAND_ENVELOPE_UPSTREAM_REF,
};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::str::FromStr;
use thiserror::Error;

pub const EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_ID: &str =
    "F-ExoticQuantRedactedFirstTokenProbePreflightGate";
pub const EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_CURSOR: &str =
    "exotic_quant_redacted_first_token_probe_preflight_gate";
pub const EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_NEXT_CURSOR: &str =
    "exotic_quant_owner_approved_redacted_first_token_runtime_probe_gate";
pub const EXOTIC_QUANT_DRY_RUN_TRANSCRIPT_UPSTREAM_REF: &str =
    "artifact:falsifiers/exotic_quant_owner_approved_dry_run_transcript_preflight_gate/result.json#F-ExoticQuantOwnerApprovedDryRunTranscriptPreflightGate";
pub const REDACTED_FIRST_TOKEN_METADATA_BUDGET_BYTES: u64 = 128 * 1024;
pub const REDACTED_FIRST_TOKEN_MEMORY_SAMPLE_SLOT_COUNT: usize = 4;

// UAS: uas:exotic-quant-redacted-first-token:surface
// Plane: Controller
// Residency: preflight contract only; no runtime lane is opened.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RedactedFirstTokenProbeSurface {
    LlamaCppGgufOneTokenPreflight,
    TransformersPythonOneTokenQuarantinePreflight,
    ServerOnlyFirstTokenProbeDenied,
}

// UAS: uas:exotic-quant-redacted-first-token:state
// Plane: Verification
// Residency: fail-closed first-token preflight state.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RedactedFirstTokenProbeState {
    MacCandidateOwnerApprovalPendingRedactedFirstTokenPreflight,
    ServerOnlyFirstTokenProbeDenied,
}

// UAS: uas:exotic-quant-redacted-first-token:policy
// Plane: Controller + Verification
// Residency: privacy and runtime guard contract before owner-approved probing.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RedactedFirstTokenProbePolicy {
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub raw_prompt_text_denied: bool,
    pub prompt_digest_required: bool,
    pub prompt_digest_algorithm_bound: bool,
    pub raw_token_text_denied: bool,
    pub first_token_digest_required: bool,
    pub first_token_digest_future_only: bool,
    pub stdout_stderr_capture_allowed: bool,
    pub stdout_stderr_redaction_bound: bool,
    pub hidden_chain_denied: bool,
    pub provider_fallback_denied: bool,
    pub one_token_bound: bool,
    pub predict_greater_than_one_denied: bool,
    pub context_batch_bounds_required: bool,
    pub memory_samples_required: bool,
    pub cancellation_required: bool,
    pub teardown_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub no_runtime_execution: bool,
    pub no_model_bytes: bool,
    pub no_product_promotion: bool,
    pub no_hidden_authority: bool,
}

impl RedactedFirstTokenProbePolicy {
    pub fn preflight(owner_approval_required: bool) -> Self {
        Self {
            owner_approval_required,
            owner_approval_granted: false,
            raw_prompt_text_denied: true,
            prompt_digest_required: true,
            prompt_digest_algorithm_bound: true,
            raw_token_text_denied: true,
            first_token_digest_required: true,
            first_token_digest_future_only: true,
            stdout_stderr_capture_allowed: false,
            stdout_stderr_redaction_bound: true,
            hidden_chain_denied: true,
            provider_fallback_denied: true,
            one_token_bound: true,
            predict_greater_than_one_denied: true,
            context_batch_bounds_required: true,
            memory_samples_required: true,
            cancellation_required: true,
            teardown_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            no_runtime_execution: true,
            no_model_bytes: true,
            no_product_promotion: true,
            no_hidden_authority: true,
        }
    }
}

// UAS: uas:exotic-quant-redacted-first-token:byte-ledger
// Plane: Verification
// Residency: byte accounting; raw prompt, token, runtime, and model bytes are zero.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RedactedFirstTokenProbeByteLedger {
    pub metadata_bytes_read: u64,
    pub schema_bytes_serialized: u64,
    pub prompt_template_descriptor_bytes: u64,
    pub raw_prompt_bytes_captured: u64,
    pub prompt_digest_bytes_captured: u64,
    pub raw_token_bytes_captured: u64,
    pub first_token_digest_bytes_captured: u64,
    pub stdout_bytes_captured: u64,
    pub stderr_bytes_captured: u64,
    pub command_execution_count: u32,
    pub model_artifact_bytes_read: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_bytes_read: u64,
    pub network_bytes_read: u64,
    pub source_code_bytes_imported: u64,
    pub benchmark_bytes_read: u64,
    pub product_surface_bytes_written: u64,
}

impl RedactedFirstTokenProbeByteLedger {
    pub fn metadata_only(
        metadata_bytes_read: u64,
        schema_bytes_serialized: u64,
        prompt_template_descriptor_bytes: u64,
    ) -> Self {
        Self {
            metadata_bytes_read,
            schema_bytes_serialized,
            prompt_template_descriptor_bytes,
            raw_prompt_bytes_captured: 0,
            prompt_digest_bytes_captured: 0,
            raw_token_bytes_captured: 0,
            first_token_digest_bytes_captured: 0,
            stdout_bytes_captured: 0,
            stderr_bytes_captured: 0,
            command_execution_count: 0,
            model_artifact_bytes_read: 0,
            runtime_bytes_loaded: 0,
            provider_bytes_read: 0,
            network_bytes_read: 0,
            source_code_bytes_imported: 0,
            benchmark_bytes_read: 0,
            product_surface_bytes_written: 0,
        }
    }

    fn validate(&self) -> Result<(), RedactedFirstTokenProbePreflightError> {
        if self.metadata_bytes_read == 0
            || self.schema_bytes_serialized == 0
            || self.prompt_template_descriptor_bytes == 0
        {
            return Err(RedactedFirstTokenProbePreflightError::MissingMetadataBytes);
        }
        if self.metadata_bytes_read > REDACTED_FIRST_TOKEN_METADATA_BUDGET_BYTES {
            return Err(
                RedactedFirstTokenProbePreflightError::MetadataBudgetExceeded {
                    bytes: self.metadata_bytes_read,
                    budget: REDACTED_FIRST_TOKEN_METADATA_BUDGET_BYTES,
                },
            );
        }
        if self.command_execution_count != 0 {
            return Err(RedactedFirstTokenProbePreflightError::CommandExecuted);
        }
        if self.raw_prompt_bytes_captured != 0
            || self.prompt_digest_bytes_captured != 0
            || self.raw_token_bytes_captured != 0
            || self.first_token_digest_bytes_captured != 0
            || self.stdout_bytes_captured != 0
            || self.stderr_bytes_captured != 0
            || self.model_artifact_bytes_read != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_bytes_read != 0
            || self.network_bytes_read != 0
            || self.source_code_bytes_imported != 0
            || self.benchmark_bytes_read != 0
            || self.product_surface_bytes_written != 0
        {
            return Err(RedactedFirstTokenProbePreflightError::LiveBytesObserved);
        }
        Ok(())
    }
}

// UAS: uas:exotic-quant-redacted-first-token:proof-refs
// Plane: Verification
// Residency: proof anchors for the later owner-approved runtime probe.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RedactedFirstTokenProbeProofRefs {
    pub upstream_dry_run_transcript_ref: String,
    pub upstream_transcript_card_id: String,
    pub owner_lease_ref: String,
    pub prompt_template_ref: String,
    pub prompt_digest_policy_ref: String,
    pub token_digest_policy_ref: String,
    pub output_redaction_ref: String,
    pub one_token_bound_ref: String,
    pub context_batch_bound_ref: String,
    pub memory_sampling_ref: String,
    pub cancellation_teardown_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub lane_caveat_ref: String,
    pub non_promotion_ref: String,
}

impl RedactedFirstTokenProbeProofRefs {
    fn for_transcript(
        upstream_dry_run_transcript_ref: &str,
        card: &OwnerApprovedDryRunTranscriptPreflightCard,
    ) -> Self {
        let pin = card.source_pin.as_str();
        Self {
            upstream_dry_run_transcript_ref: upstream_dry_run_transcript_ref.to_string(),
            upstream_transcript_card_id: card.gate_id.clone(),
            owner_lease_ref: format!("owner_lease:first_token_runtime_probe_pending:{pin}"),
            prompt_template_ref: format!("prompt_template:synthetic_redacted_descriptor:{pin}"),
            prompt_digest_policy_ref: format!(
                "prompt_digest:sha256_redacted_descriptor_only:{pin}"
            ),
            token_digest_policy_ref: format!("token_digest:sha256_first_token_future_only:{pin}"),
            output_redaction_ref: format!("redaction:no_stdout_stderr_raw_token:{pin}"),
            one_token_bound_ref: format!("one_token_bound:max_new_tokens_1:{pin}"),
            context_batch_bound_ref: format!("context_batch_bound:ctx2048_batch1:{pin}"),
            memory_sampling_ref: format!("memory_sampling:preflight_slots_4:{pin}"),
            cancellation_teardown_ref: format!("teardown:cancel_close_wait_kill_tree:{pin}"),
            rollback_ref: format!("rollback:first_token_probe_no_mutation:{pin}"),
            run_event_log_ref: format!("run_event_log:redacted_first_token_pending:{pin}"),
            answer_packet_ref: format!("answer_packet:redacted_first_token_pending:{pin}"),
            lane_caveat_ref: format!("lane_caveat:runtime_not_proven:{pin}"),
            non_promotion_ref: format!("non_promotion:t1_metadata_only:{pin}"),
        }
    }

    fn validate(&self) -> Result<(), RedactedFirstTokenProbePreflightError> {
        require_artifact_ref(
            &self.upstream_dry_run_transcript_ref,
            "upstream_dry_run_transcript_ref",
            "exotic_quant_owner_approved_dry_run_transcript_preflight_gate",
        )?;
        for (field, value) in [
            (
                "upstream_transcript_card_id",
                self.upstream_transcript_card_id.as_str(),
            ),
            ("owner_lease_ref", self.owner_lease_ref.as_str()),
            ("prompt_template_ref", self.prompt_template_ref.as_str()),
            (
                "prompt_digest_policy_ref",
                self.prompt_digest_policy_ref.as_str(),
            ),
            (
                "token_digest_policy_ref",
                self.token_digest_policy_ref.as_str(),
            ),
            ("output_redaction_ref", self.output_redaction_ref.as_str()),
            ("one_token_bound_ref", self.one_token_bound_ref.as_str()),
            (
                "context_batch_bound_ref",
                self.context_batch_bound_ref.as_str(),
            ),
            ("memory_sampling_ref", self.memory_sampling_ref.as_str()),
            (
                "cancellation_teardown_ref",
                self.cancellation_teardown_ref.as_str(),
            ),
            ("rollback_ref", self.rollback_ref.as_str()),
            ("run_event_log_ref", self.run_event_log_ref.as_str()),
            ("answer_packet_ref", self.answer_packet_ref.as_str()),
            ("lane_caveat_ref", self.lane_caveat_ref.as_str()),
            ("non_promotion_ref", self.non_promotion_ref.as_str()),
        ] {
            validate_token(field, value)?;
        }
        Ok(())
    }
}

// UAS: uas:exotic-quant-redacted-first-token:card
// Plane: Controller + Verification
// Residency: first-token probe contract only; no token exists yet.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RedactedFirstTokenProbePreflightCard {
    pub gate_id: String,
    pub model_id: String,
    pub source_pin: String,
    pub upstream_transcript_card_id: String,
    pub surface: RedactedFirstTokenProbeSurface,
    pub state: RedactedFirstTokenProbeState,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub server_only_probe_denied: bool,
    pub prompt_template_visible: bool,
    pub prompt_digest_policy_bound: bool,
    pub raw_prompt_text_present: bool,
    pub raw_user_prompt_present: bool,
    pub first_token_digest_policy_bound: bool,
    pub first_token_observed: bool,
    pub first_token_digest_present: bool,
    pub raw_token_text_present: bool,
    pub max_new_tokens: u32,
    pub context_cap_tokens: u32,
    pub batch_cap: u32,
    pub memory_sample_slots: Vec<String>,
    pub command_execution_allowed: bool,
    pub runtime_probe_allowed: bool,
    pub model_path_opened: bool,
    pub local_artifact_verified: bool,
    pub lane_caveat_bound: bool,
    pub policy: RedactedFirstTokenProbePolicy,
    pub byte_ledger: RedactedFirstTokenProbeByteLedger,
    pub proof_refs: RedactedFirstTokenProbeProofRefs,
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

impl RedactedFirstTokenProbePreflightCard {
    fn from_transcript_card(
        upstream_dry_run_transcript_ref: &str,
        card: &OwnerApprovedDryRunTranscriptPreflightCard,
    ) -> Self {
        let mac_candidate = matches!(
            card.state,
            OwnerApprovedDryRunTranscriptState::MacCandidateOwnerApprovalPendingTranscriptPreflight
        );
        let surface = match card.surface {
            OwnerApprovedDryRunTranscriptSurface::LlamaCppProcessDryRun => {
                RedactedFirstTokenProbeSurface::LlamaCppGgufOneTokenPreflight
            }
            OwnerApprovedDryRunTranscriptSurface::TransformersPythonQuarantineDryRun => {
                RedactedFirstTokenProbeSurface::TransformersPythonOneTokenQuarantinePreflight
            }
            OwnerApprovedDryRunTranscriptSurface::ServerOnlyTranscriptDenied => {
                RedactedFirstTokenProbeSurface::ServerOnlyFirstTokenProbeDenied
            }
        };
        let state = if mac_candidate {
            RedactedFirstTokenProbeState::MacCandidateOwnerApprovalPendingRedactedFirstTokenPreflight
        } else {
            RedactedFirstTokenProbeState::ServerOnlyFirstTokenProbeDenied
        };
        let memory_sample_slots = (0..REDACTED_FIRST_TOKEN_MEMORY_SAMPLE_SLOT_COUNT)
            .map(|slot| format!("memory_sample_slot:{slot}:{}", card.source_pin))
            .collect::<Vec<_>>();
        Self {
            gate_id: format!(
                "redacted_first_token_preflight:{}:{}",
                card.model_id, card.source_pin
            ),
            model_id: card.model_id.clone(),
            source_pin: card.source_pin.clone(),
            upstream_transcript_card_id: card.gate_id.clone(),
            surface,
            state,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
            owner_approval_required: mac_candidate,
            owner_approval_granted: false,
            server_only_probe_denied: !mac_candidate,
            prompt_template_visible: true,
            prompt_digest_policy_bound: true,
            raw_prompt_text_present: false,
            raw_user_prompt_present: false,
            first_token_digest_policy_bound: true,
            first_token_observed: false,
            first_token_digest_present: false,
            raw_token_text_present: false,
            max_new_tokens: 1,
            context_cap_tokens: 2_048,
            batch_cap: 1,
            memory_sample_slots,
            command_execution_allowed: false,
            runtime_probe_allowed: false,
            model_path_opened: false,
            local_artifact_verified: false,
            lane_caveat_bound: true,
            policy: RedactedFirstTokenProbePolicy::preflight(mac_candidate),
            byte_ledger: RedactedFirstTokenProbeByteLedger::metadata_only(24_576, 8_192, 4_096),
            proof_refs: RedactedFirstTokenProbeProofRefs::for_transcript(
                upstream_dry_run_transcript_ref,
                card,
            ),
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
            next_cursor: EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_NEXT_CURSOR
                .to_string(),
            user_visible_summary: format!(
                "Redacted first-token preflight for {model} from {source} defines only the \
                 future owner-approved one-token contract: synthetic prompt descriptor, prompt \
                 digest policy, first-token digest policy, bounded context and batch, memory \
                 samples, cancellation, teardown, rollback, RunEventLog, and AnswerPacket. It \
                 captures no raw prompt, raw token, stdout, stderr, model bytes, or runtime bytes.",
                model = card.model_id,
                source = card.source_pin
            ),
        }
    }

    pub fn validate(&self) -> Result<(), RedactedFirstTokenProbePreflightError> {
        validate_token("gate_id", &self.gate_id)?;
        validate_token("model_id", &self.model_id)?;
        validate_token("source_pin", &self.source_pin)?;
        validate_token(
            "upstream_transcript_card_id",
            &self.upstream_transcript_card_id,
        )?;
        validate_text(
            "user_visible_summary",
            &self.user_visible_summary,
            220,
            1200,
        )?;
        if !expected_owner_path_manifest_model_ids().contains(&self.model_id.as_str()) {
            return Err(RedactedFirstTokenProbePreflightError::UnexpectedModelId(
                self.model_id.clone(),
            ));
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.promotion_tier != CompressedModelPromotionTier::T1L1Metadata
        {
            return Err(RedactedFirstTokenProbePreflightError::WrongPromotionTier {
                gate_id: self.gate_id.clone(),
            });
        }
        if self.next_cursor != EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_NEXT_CURSOR {
            return Err(RedactedFirstTokenProbePreflightError::WrongNextCursor {
                gate_id: self.gate_id.clone(),
                next_cursor: self.next_cursor.clone(),
            });
        }
        self.validate_surface_state()?;
        self.validate_policy()?;
        self.validate_memory_sample_slots()?;
        self.byte_ledger.validate()?;
        self.proof_refs.validate()?;
        if !self.prompt_template_visible
            || !self.prompt_digest_policy_bound
            || !self.first_token_digest_policy_bound
            || !self.lane_caveat_bound
            || self.raw_prompt_text_present
            || self.raw_user_prompt_present
            || self.raw_token_text_present
            || self.first_token_observed
            || self.first_token_digest_present
        {
            return Err(
                RedactedFirstTokenProbePreflightError::PrivacyBoundaryBroken {
                    gate_id: self.gate_id.clone(),
                },
            );
        }
        if self.max_new_tokens != 1
            || self.context_cap_tokens == 0
            || self.context_cap_tokens > 4_096
            || self.batch_cap != 1
            || self.command_execution_allowed
            || self.runtime_probe_allowed
            || self.model_path_opened
            || self.local_artifact_verified
        {
            return Err(
                RedactedFirstTokenProbePreflightError::RuntimeBoundaryBroken {
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
                RedactedFirstTokenProbePreflightError::FalseClaimOrHiddenAuthority {
                    gate_id: self.gate_id.clone(),
                },
            );
        }
        Ok(())
    }

    fn validate_surface_state(&self) -> Result<(), RedactedFirstTokenProbePreflightError> {
        match (self.surface, self.state) {
            (
                RedactedFirstTokenProbeSurface::LlamaCppGgufOneTokenPreflight
                | RedactedFirstTokenProbeSurface::TransformersPythonOneTokenQuarantinePreflight,
                RedactedFirstTokenProbeState::MacCandidateOwnerApprovalPendingRedactedFirstTokenPreflight,
            ) => {
                if !self.owner_approval_required
                    || self.owner_approval_granted
                    || self.server_only_probe_denied
                {
                    return Err(
                        RedactedFirstTokenProbePreflightError::OwnerApprovalBoundaryBroken {
                            gate_id: self.gate_id.clone(),
                        },
                    );
                }
            }
            (
                RedactedFirstTokenProbeSurface::ServerOnlyFirstTokenProbeDenied,
                RedactedFirstTokenProbeState::ServerOnlyFirstTokenProbeDenied,
            ) => {
                if self.owner_approval_required
                    || self.owner_approval_granted
                    || !self.server_only_probe_denied
                {
                    return Err(RedactedFirstTokenProbePreflightError::ServerOnlyBoundaryBroken {
                        gate_id: self.gate_id.clone(),
                    });
                }
            }
            _ => {
                return Err(RedactedFirstTokenProbePreflightError::WrongSurfaceState {
                    gate_id: self.gate_id.clone(),
                });
            }
        }
        Ok(())
    }

    fn validate_policy(&self) -> Result<(), RedactedFirstTokenProbePreflightError> {
        if self.policy.owner_approval_required != self.owner_approval_required
            || self.policy.owner_approval_granted
            || !self.policy.raw_prompt_text_denied
            || !self.policy.prompt_digest_required
            || !self.policy.prompt_digest_algorithm_bound
            || !self.policy.raw_token_text_denied
            || !self.policy.first_token_digest_required
            || !self.policy.first_token_digest_future_only
            || self.policy.stdout_stderr_capture_allowed
            || !self.policy.stdout_stderr_redaction_bound
            || !self.policy.hidden_chain_denied
            || !self.policy.provider_fallback_denied
            || !self.policy.one_token_bound
            || !self.policy.predict_greater_than_one_denied
            || !self.policy.context_batch_bounds_required
            || !self.policy.memory_samples_required
            || !self.policy.cancellation_required
            || !self.policy.teardown_required
            || !self.policy.rollback_required
            || !self.policy.run_event_log_required
            || !self.policy.answer_packet_required
            || !self.policy.no_runtime_execution
            || !self.policy.no_model_bytes
            || !self.policy.no_product_promotion
            || !self.policy.no_hidden_authority
        {
            return Err(RedactedFirstTokenProbePreflightError::PolicyBroken {
                gate_id: self.gate_id.clone(),
            });
        }
        Ok(())
    }

    fn validate_memory_sample_slots(&self) -> Result<(), RedactedFirstTokenProbePreflightError> {
        if self.memory_sample_slots.len() != REDACTED_FIRST_TOKEN_MEMORY_SAMPLE_SLOT_COUNT {
            return Err(
                RedactedFirstTokenProbePreflightError::MemorySampleSlotsInvalid {
                    gate_id: self.gate_id.clone(),
                },
            );
        }
        let mut seen = BTreeSet::new();
        for slot in &self.memory_sample_slots {
            validate_token("memory_sample_slot", slot)?;
            if !slot.starts_with("memory_sample_slot:") || !slot.ends_with(&self.source_pin) {
                return Err(
                    RedactedFirstTokenProbePreflightError::MemorySampleSlotsInvalid {
                        gate_id: self.gate_id.clone(),
                    },
                );
            }
            if !seen.insert(slot) {
                return Err(
                    RedactedFirstTokenProbePreflightError::MemorySampleSlotsInvalid {
                        gate_id: self.gate_id.clone(),
                    },
                );
            }
        }
        Ok(())
    }
}

// UAS: uas:exotic-quant-redacted-first-token:metrics
// Plane: Verification
// Residency: aggregate metadata-only proof metrics.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RedactedFirstTokenProbePreflightMetrics {
    pub accepted_card_count: usize,
    pub mac_candidate_owner_approval_pending_count: usize,
    pub server_only_probe_denied_count: usize,
    pub prompt_digest_policy_bound_count: usize,
    pub token_digest_policy_bound_count: usize,
    pub raw_prompt_text_present_count: usize,
    pub raw_token_text_present_count: usize,
    pub first_token_observed_count: usize,
    pub first_token_digest_present_count: usize,
    pub one_token_bound_count: usize,
    pub memory_sample_slot_total_count: usize,
    pub command_execution_count: u32,
    pub runtime_bytes_loaded: u64,
    pub model_artifact_bytes_read: u64,
    pub raw_prompt_bytes_captured: u64,
    pub raw_token_bytes_captured: u64,
    pub stdout_bytes_captured: u64,
    pub stderr_bytes_captured: u64,
    pub product_green_count: usize,
    pub hidden_authority_count: usize,
    pub next_cursor: String,
}

// UAS: uas:exotic-quant-redacted-first-token:ledger
// Plane: Verification
// Residency: metadata-only redacted first-token preflight ledger.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RedactedFirstTokenProbePreflightLedger {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_dry_run_transcript_ref: String,
    pub upstream_dry_run_transcript_address: UasAddress,
    pub cards: Vec<RedactedFirstTokenProbePreflightCard>,
    pub address: UasAddress,
    pub metrics: RedactedFirstTokenProbePreflightMetrics,
    pub metadata_only: bool,
    pub runtime_deferred_reason: String,
}

impl RedactedFirstTokenProbePreflightLedger {
    pub fn new(
        upstream_dry_run_transcript_ref: &str,
        upstream_dry_run_transcript_address: UasAddress,
        mut cards: Vec<RedactedFirstTokenProbePreflightCard>,
    ) -> Result<Self, RedactedFirstTokenProbePreflightError> {
        require_artifact_ref(
            upstream_dry_run_transcript_ref,
            "upstream_dry_run_transcript_ref",
            "exotic_quant_owner_approved_dry_run_transcript_preflight_gate",
        )?;
        validate_uas_address(&upstream_dry_run_transcript_address)
            .map_err(|_| RedactedFirstTokenProbePreflightError::BadUpstreamAddress)?;
        cards.sort_by(|a, b| a.gate_id.cmp(&b.gate_id));
        if cards.is_empty() {
            return Err(RedactedFirstTokenProbePreflightError::EmptyCardSet);
        }
        let mut seen_gate_ids = BTreeSet::new();
        let mut seen_models = BTreeSet::new();
        for card in &cards {
            card.validate()?;
            if !seen_gate_ids.insert(card.gate_id.as_str()) {
                return Err(RedactedFirstTokenProbePreflightError::DuplicateGateId(
                    card.gate_id.clone(),
                ));
            }
            seen_models.insert(card.model_id.as_str());
        }
        for expected in expected_owner_path_manifest_model_ids() {
            if !seen_models.contains(expected) {
                return Err(RedactedFirstTokenProbePreflightError::MissingExpectedModel(
                    expected.to_string(),
                ));
            }
        }
        let metrics = metrics_for_cards(&cards);
        if metrics.accepted_card_count != cards.len()
            || metrics.mac_candidate_owner_approval_pending_count == 0
            || metrics.server_only_probe_denied_count == 0
            || metrics.prompt_digest_policy_bound_count != cards.len()
            || metrics.token_digest_policy_bound_count != cards.len()
            || metrics.raw_prompt_text_present_count != 0
            || metrics.raw_token_text_present_count != 0
            || metrics.first_token_observed_count != 0
            || metrics.first_token_digest_present_count != 0
            || metrics.one_token_bound_count != cards.len()
            || metrics.command_execution_count != 0
            || metrics.runtime_bytes_loaded != 0
            || metrics.model_artifact_bytes_read != 0
            || metrics.raw_prompt_bytes_captured != 0
            || metrics.raw_token_bytes_captured != 0
            || metrics.stdout_bytes_captured != 0
            || metrics.stderr_bytes_captured != 0
            || metrics.product_green_count != 0
            || metrics.hidden_authority_count != 0
        {
            return Err(RedactedFirstTokenProbePreflightError::MetricsBroken);
        }
        let address = UasAddress::new(
            UasKind::Other(EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_ID.to_string()),
            &ledger_preimage(
                upstream_dry_run_transcript_ref,
                &upstream_dry_run_transcript_address,
                &cards,
                &metrics,
            ),
            1,
        );
        validate_uas_address(&address)
            .map_err(|_| RedactedFirstTokenProbePreflightError::BadLedgerAddress)?;
        Ok(Self {
            falsifier_id: EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_ID.to_string(),
            cursor: EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_CURSOR.to_string(),
            next_cursor: EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_NEXT_CURSOR
                .to_string(),
            upstream_dry_run_transcript_ref: upstream_dry_run_transcript_ref.to_string(),
            upstream_dry_run_transcript_address,
            cards,
            address,
            metrics,
            metadata_only: true,
            runtime_deferred_reason: "Redacted first-token preflight is a Pro Gated T1 contract. It prepares the future owner-approved one-token probe schema while forbidding raw prompts, raw tokens, stdout/stderr capture, command execution, model-path opens, runtime bytes, provider fallback, hidden route authority, benchmark-as-fit claims, and L2/L3/product promotion.".to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), RedactedFirstTokenProbePreflightError> {
        if self.falsifier_id != EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_ID
            || self.cursor != EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_CURSOR
            || self.next_cursor
                != EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_NEXT_CURSOR
            || !self.metadata_only
            || self.runtime_deferred_reason.len() < 180
        {
            return Err(RedactedFirstTokenProbePreflightError::LedgerHeaderBroken);
        }
        let rebuilt = Self::new(
            &self.upstream_dry_run_transcript_ref,
            self.upstream_dry_run_transcript_address.clone(),
            self.cards.clone(),
        )?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(RedactedFirstTokenProbePreflightError::LedgerDigestMismatch);
        }
        Ok(())
    }
}

pub fn canonical_redacted_first_token_probe_preflight_cards(
    upstream_dry_run_transcript_ref: &str,
    transcript_cards: &[OwnerApprovedDryRunTranscriptPreflightCard],
) -> Vec<RedactedFirstTokenProbePreflightCard> {
    transcript_cards
        .iter()
        .map(|card| {
            RedactedFirstTokenProbePreflightCard::from_transcript_card(
                upstream_dry_run_transcript_ref,
                card,
            )
        })
        .collect()
}

pub fn canonical_redacted_first_token_probe_preflight_ledger(
    upstream_dry_run_transcript_address: UasAddress,
) -> Result<RedactedFirstTokenProbePreflightLedger, RedactedFirstTokenProbePreflightError> {
    let command_cards =
        canonical_crash_safe_command_envelope_cards(EXOTIC_QUANT_BYTE_ENVELOPE_UPSTREAM_REF);
    let transcript_cards = canonical_owner_approved_dry_run_transcript_preflight_cards(
        EXOTIC_QUANT_COMMAND_ENVELOPE_UPSTREAM_REF,
        &command_cards,
    );
    let cards = canonical_redacted_first_token_probe_preflight_cards(
        EXOTIC_QUANT_DRY_RUN_TRANSCRIPT_UPSTREAM_REF,
        &transcript_cards,
    );
    RedactedFirstTokenProbePreflightLedger::new(
        EXOTIC_QUANT_DRY_RUN_TRANSCRIPT_UPSTREAM_REF,
        upstream_dry_run_transcript_address,
        cards,
    )
}

fn metrics_for_cards(
    cards: &[RedactedFirstTokenProbePreflightCard],
) -> RedactedFirstTokenProbePreflightMetrics {
    RedactedFirstTokenProbePreflightMetrics {
        accepted_card_count: cards.len(),
        mac_candidate_owner_approval_pending_count: cards
            .iter()
            .filter(|card| {
                card.state
                    == RedactedFirstTokenProbeState::MacCandidateOwnerApprovalPendingRedactedFirstTokenPreflight
            })
            .count(),
        server_only_probe_denied_count: cards
            .iter()
            .filter(|card| card.state == RedactedFirstTokenProbeState::ServerOnlyFirstTokenProbeDenied)
            .count(),
        prompt_digest_policy_bound_count: cards
            .iter()
            .filter(|card| card.prompt_digest_policy_bound)
            .count(),
        token_digest_policy_bound_count: cards
            .iter()
            .filter(|card| card.first_token_digest_policy_bound)
            .count(),
        raw_prompt_text_present_count: cards
            .iter()
            .filter(|card| card.raw_prompt_text_present || card.raw_user_prompt_present)
            .count(),
        raw_token_text_present_count: cards
            .iter()
            .filter(|card| card.raw_token_text_present)
            .count(),
        first_token_observed_count: cards
            .iter()
            .filter(|card| card.first_token_observed)
            .count(),
        first_token_digest_present_count: cards
            .iter()
            .filter(|card| card.first_token_digest_present)
            .count(),
        one_token_bound_count: cards
            .iter()
            .filter(|card| card.max_new_tokens == 1 && card.batch_cap == 1)
            .count(),
        memory_sample_slot_total_count: cards
            .iter()
            .map(|card| card.memory_sample_slots.len())
            .sum(),
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
        raw_prompt_bytes_captured: cards
            .iter()
            .map(|card| card.byte_ledger.raw_prompt_bytes_captured)
            .sum(),
        raw_token_bytes_captured: cards
            .iter()
            .map(|card| card.byte_ledger.raw_token_bytes_captured)
            .sum(),
        stdout_bytes_captured: cards
            .iter()
            .map(|card| card.byte_ledger.stdout_bytes_captured)
            .sum(),
        stderr_bytes_captured: cards
            .iter()
            .map(|card| card.byte_ledger.stderr_bytes_captured)
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
        next_cursor: EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_NEXT_CURSOR
            .to_string(),
    }
}

fn ledger_preimage(
    upstream_dry_run_transcript_ref: &str,
    upstream_dry_run_transcript_address: &UasAddress,
    cards: &[RedactedFirstTokenProbePreflightCard],
    metrics: &RedactedFirstTokenProbePreflightMetrics,
) -> Vec<u8> {
    let mut preimage = Vec::with_capacity(12_288);
    preimage
        .extend_from_slice(EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_ID.as_bytes());
    preimage.extend_from_slice(
        EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_CURSOR.as_bytes(),
    );
    preimage.extend_from_slice(
        EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_NEXT_CURSOR.as_bytes(),
    );
    preimage.extend_from_slice(upstream_dry_run_transcript_ref.as_bytes());
    preimage.extend_from_slice(upstream_dry_run_transcript_address.to_string().as_bytes());
    for card in cards {
        preimage.extend_from_slice(card.gate_id.as_bytes());
        preimage.extend_from_slice(card.model_id.as_bytes());
        preimage.extend_from_slice(card.source_pin.as_bytes());
        preimage.extend_from_slice(card.upstream_transcript_card_id.as_bytes());
        preimage.extend_from_slice(format!("{:?}", card.surface).as_bytes());
        preimage.extend_from_slice(format!("{:?}", card.state).as_bytes());
        preimage.extend_from_slice(card.proof_refs.prompt_digest_policy_ref.as_bytes());
        preimage.extend_from_slice(card.proof_refs.token_digest_policy_ref.as_bytes());
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
) -> Result<(), RedactedFirstTokenProbePreflightError> {
    validate_token(field, value)?;
    if !value.starts_with("artifact:falsifiers/")
        || !value.contains(expected_slug)
        || !value.contains("/result.json#")
    {
        return Err(RedactedFirstTokenProbePreflightError::BadArtifactRef {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_uas_address(address: &UasAddress) -> Result<(), RedactedFirstTokenProbePreflightError> {
    let rendered = address.to_string();
    let reparsed = UasAddress::from_str(&rendered).map_err(|_| {
        RedactedFirstTokenProbePreflightError::BadAddressWireFormat(rendered.clone())
    })?;
    if &reparsed != address {
        return Err(RedactedFirstTokenProbePreflightError::BadAddressWireFormat(
            rendered,
        ));
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), RedactedFirstTokenProbePreflightError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(RedactedFirstTokenProbePreflightError::InvalidToken {
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
) -> Result<(), RedactedFirstTokenProbePreflightError> {
    if value.trim().len() < min_len
        || value.len() > max_len
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(RedactedFirstTokenProbePreflightError::InvalidText {
            field,
            len: value.len(),
        });
    }
    Ok(())
}

// UAS: uas:exotic-quant-redacted-first-token:error
// Plane: Verification
// Residency: fail-closed validation errors; no runtime side effects.
#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum RedactedFirstTokenProbePreflightError {
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
    #[error("privacy boundary broken for {gate_id}")]
    PrivacyBoundaryBroken { gate_id: String },
    #[error("policy broken for {gate_id}")]
    PolicyBroken { gate_id: String },
    #[error("memory sample slots invalid for {gate_id}")]
    MemorySampleSlotsInvalid { gate_id: String },
    #[error("missing metadata bytes")]
    MissingMetadataBytes,
    #[error("metadata budget exceeded: {bytes}>{budget}")]
    MetadataBudgetExceeded { bytes: u64, budget: u64 },
    #[error("command executed")]
    CommandExecuted,
    #[error("live bytes observed")]
    LiveBytesObserved,
    #[error("runtime boundary broken for {gate_id}")]
    RuntimeBoundaryBroken { gate_id: String },
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
            UasKind::Other("F-ExoticQuantOwnerApprovedDryRunTranscriptPreflightGate".to_string()),
            b"stable dry run transcript test address",
            1,
        )
    }

    fn canonical_ledger() -> RedactedFirstTokenProbePreflightLedger {
        canonical_redacted_first_token_probe_preflight_ledger(test_upstream_address())
            .expect("canonical redacted first-token preflight ledger should validate")
    }

    #[test]
    fn accepts_canonical_redacted_first_token_preflight_without_execution() {
        let ledger = canonical_ledger();
        ledger.validate().expect("canonical ledger validates");
        assert_eq!(
            ledger.cursor,
            EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_CURSOR
        );
        assert_eq!(
            ledger.next_cursor,
            EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_NEXT_CURSOR
        );
        assert!(ledger.metadata_only);
        assert_eq!(ledger.metrics.accepted_card_count, 5);
        assert_eq!(ledger.metrics.first_token_observed_count, 0);
        assert_eq!(ledger.metrics.raw_prompt_text_present_count, 0);
        assert_eq!(ledger.metrics.raw_token_text_present_count, 0);
        assert_eq!(ledger.metrics.command_execution_count, 0);
        assert_eq!(ledger.metrics.runtime_bytes_loaded, 0);
    }

    #[test]
    fn rejects_prompt_and_token_leakage() {
        let mut ledger = canonical_ledger();
        ledger.cards[0].raw_prompt_text_present = true;
        assert!(matches!(
            RedactedFirstTokenProbePreflightLedger::new(
                &ledger.upstream_dry_run_transcript_ref,
                ledger.upstream_dry_run_transcript_address.clone(),
                ledger.cards.clone(),
            ),
            Err(RedactedFirstTokenProbePreflightError::PrivacyBoundaryBroken { .. })
        ));

        let mut ledger = canonical_ledger();
        ledger.cards[0].first_token_observed = true;
        ledger.cards[0].raw_token_text_present = true;
        assert!(matches!(
            RedactedFirstTokenProbePreflightLedger::new(
                &ledger.upstream_dry_run_transcript_ref,
                ledger.upstream_dry_run_transcript_address,
                ledger.cards,
            ),
            Err(RedactedFirstTokenProbePreflightError::PrivacyBoundaryBroken { .. })
        ));
    }

    #[test]
    fn rejects_unbounded_runtime_and_byte_leaks() {
        let mut ledger = canonical_ledger();
        ledger.cards[0].max_new_tokens = 2;
        assert!(matches!(
            RedactedFirstTokenProbePreflightLedger::new(
                &ledger.upstream_dry_run_transcript_ref,
                ledger.upstream_dry_run_transcript_address.clone(),
                ledger.cards.clone(),
            ),
            Err(RedactedFirstTokenProbePreflightError::RuntimeBoundaryBroken { .. })
        ));

        let mut ledger = canonical_ledger();
        ledger.cards[0].byte_ledger.runtime_bytes_loaded = 1;
        assert_eq!(
            RedactedFirstTokenProbePreflightLedger::new(
                &ledger.upstream_dry_run_transcript_ref,
                ledger.upstream_dry_run_transcript_address,
                ledger.cards,
            ),
            Err(RedactedFirstTokenProbePreflightError::LiveBytesObserved)
        );
    }

    #[test]
    fn rejects_hidden_authority_and_false_green_claims() {
        let mut ledger = canonical_ledger();
        ledger.cards[0].hidden_route_authority = true;
        assert!(matches!(
            RedactedFirstTokenProbePreflightLedger::new(
                &ledger.upstream_dry_run_transcript_ref,
                ledger.upstream_dry_run_transcript_address.clone(),
                ledger.cards.clone(),
            ),
            Err(RedactedFirstTokenProbePreflightError::FalseClaimOrHiddenAuthority { .. })
        ));

        let mut ledger = canonical_ledger();
        ledger.cards[0].l3_wrv_green = true;
        assert!(matches!(
            RedactedFirstTokenProbePreflightLedger::new(
                &ledger.upstream_dry_run_transcript_ref,
                ledger.upstream_dry_run_transcript_address,
                ledger.cards,
            ),
            Err(RedactedFirstTokenProbePreflightError::FalseClaimOrHiddenAuthority { .. })
        ));
    }

    #[test]
    fn produces_stable_digest_for_sorted_cards() {
        let ledger = canonical_ledger();
        let mut reversed = ledger.cards.clone();
        reversed.reverse();
        let rebuilt = RedactedFirstTokenProbePreflightLedger::new(
            &ledger.upstream_dry_run_transcript_ref,
            ledger.upstream_dry_run_transcript_address.clone(),
            reversed,
        )
        .expect("reversed cards sort into same ledger");
        assert_eq!(ledger.address, rebuilt.address);
        assert_eq!(ledger.metrics, rebuilt.metrics);
    }
}
