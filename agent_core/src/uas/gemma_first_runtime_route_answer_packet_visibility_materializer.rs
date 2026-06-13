//! Gemma first-runtime route AnswerPacket visibility materializer.
//!
//! This bridge consumes the digest-only System G dry-run route packet and emits
//! a digest-only visibility packet for later settings/diagnostics/WRV work. It
//! does not emit a user-visible AnswerPacket, perform admission, mutate routes,
//! execute commands, load model bytes, or claim Gemma product capability.

use serde::{Deserialize, Serialize};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{
    validate_first_runtime_system_g_dry_run_route_packet,
    GemmaFirstRuntimeSystemGDryRunRoutePacket,
    GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError, UasAddress, UasKind,
    GEMMA_FIRST_RUNTIME_SYSTEM_G_DRY_RUN_ROUTE_PACKET_NEXT_CURSOR,
};

pub const GEMMA_FIRST_RUNTIME_ROUTE_ANSWER_PACKET_VISIBILITY_SCHEMA_VERSION: &str =
    "gemma-first-runtime-route-answer-packet-visibility-v1";
pub const GEMMA_FIRST_RUNTIME_ROUTE_ANSWER_PACKET_VISIBILITY_CURSOR: &str =
    "gemma_direct_harness_owner_approved_route_answer_packet_visibility_gate";
pub const GEMMA_FIRST_RUNTIME_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_ID: &str =
    "F-GemmaDirectHarnessOwnerApprovedRouteAnswerPacketVisibilityGate";
pub const GEMMA_FIRST_RUNTIME_ROUTE_ANSWER_PACKET_VISIBILITY_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_settings_diagnostics_wrv_gate";

const MAX_VISIBILITY_METADATA_BYTES: u64 = 384 * 1024;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GemmaFirstRuntimeRouteAnswerPacketVisibilityRequest {
    pub system_g_dry_run_packet: GemmaFirstRuntimeSystemGDryRunRoutePacket,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaFirstRuntimeRouteAnswerPacketVisibilityPacket {
    pub schema_version: String,
    pub route_answer_packet_visibility_gate_id: String,
    pub upstream_dry_run_route_packet_digest: String,
    pub selected_model_id: String,
    pub model_identity_digest: String,
    pub llama_cli_identity_digest: String,
    pub runtime_lane: String,
    pub answer_packet_template_digest: String,
    pub visible_model_identity_digest: String,
    pub visible_runtime_lane_digest: String,
    pub visible_route_status_digest: String,
    pub visible_route_caveat_digest: String,
    pub visible_budget_summary_digest: String,
    pub visible_memory_headroom_digest: String,
    pub visible_kv_budget_digest: String,
    pub visible_latency_budget_digest: String,
    pub visible_privacy_class_digest: String,
    pub visible_mas_pro_boundary_digest: String,
    pub visible_scope_rex_digest: String,
    pub visible_sovereign_gate_digest: String,
    pub visible_fallback_digest: String,
    pub visible_abstention_digest: String,
    pub visible_cancellation_digest: String,
    pub visible_rollback_ref: String,
    pub visible_run_event_log_ref: String,
    pub visible_no_default_model_mutation_digest: String,
    pub visible_no_hidden_authority_digest: String,
    pub visible_non_promotion_digest: String,
    pub settings_surface_copy_digest: String,
    pub diagnostics_surface_copy_digest: String,
    pub route_explanation_digest: String,
    pub rejected_candidate_summary_digest: String,
    pub user_action_required_digest: String,
    pub no_quality_claim_digest: String,
    pub no_live_default_claim_digest: String,
    pub no_large_model_bypass_digest: String,
    pub upstream_dry_run_route_packet_ready: bool,
    pub visibility_packet_materialized_count: u64,
    pub settings_diagnostics_wrv_ready: bool,
    pub future_visibility_packet_present: bool,
    pub future_visibility_packet_bytes_read: u64,
    pub answer_packet_emitted_to_user_count: u64,
    pub system_g_dry_run_performed_count: u64,
    pub admission_performed_count: u64,
    pub route_priority_mutation_count: u64,
    pub runtime_router_mutation_count: u64,
    pub system_g_mutation_count: u64,
    pub default_model_mutation_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub process_spawned_count: u64,
    pub runtime_replay_performed_count: u64,
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
    pub quality_claim: bool,
    pub live_gemma_claim: bool,
    pub l2_l3_t4_claim: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub reviewer_visible_summary: String,
    pub metadata_bytes: u64,
    pub next_cursor: String,
    pub visibility_packet_digest: String,
}

#[derive(Debug)]
pub enum GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError {
    DryRun(GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError),
    PacketInvalid(&'static str),
    Serialize(serde_json::Error),
}

impl fmt::Display for GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::DryRun(error) => write!(f, "System G dry-run packet invalid: {error}"),
            Self::PacketInvalid(reason) => write!(f, "visibility packet invalid: {reason}"),
            Self::Serialize(error) => write!(f, "visibility packet serialization error: {error}"),
        }
    }
}

impl std::error::Error for GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError {}

impl From<GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError>
    for GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError
{
    fn from(value: GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError) -> Self {
        Self::DryRun(value)
    }
}

impl From<serde_json::Error> for GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError {
    fn from(value: serde_json::Error) -> Self {
        Self::Serialize(value)
    }
}

pub fn materialize_first_runtime_route_answer_packet_visibility(
    request: &GemmaFirstRuntimeRouteAnswerPacketVisibilityRequest,
) -> Result<
    GemmaFirstRuntimeRouteAnswerPacketVisibilityPacket,
    GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError,
> {
    let dry_run = &request.system_g_dry_run_packet;
    validate_first_runtime_system_g_dry_run_route_packet(dry_run)?;
    if dry_run.next_cursor != GEMMA_FIRST_RUNTIME_SYSTEM_G_DRY_RUN_ROUTE_PACKET_NEXT_CURSOR {
        return Err(
            GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError::PacketInvalid(
                "system_g_dry_run_packet.next_cursor",
            ),
        );
    }
    if !dry_run.route_answer_packet_visibility_ready {
        return Err(
            GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError::PacketInvalid(
                "route_answer_packet_visibility_ready",
            ),
        );
    }

    let mut packet = GemmaFirstRuntimeRouteAnswerPacketVisibilityPacket {
        schema_version: GEMMA_FIRST_RUNTIME_ROUTE_ANSWER_PACKET_VISIBILITY_SCHEMA_VERSION
            .to_string(),
        route_answer_packet_visibility_gate_id:
            GEMMA_FIRST_RUNTIME_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_ID.to_string(),
        upstream_dry_run_route_packet_digest: dry_run.route_packet_digest.clone(),
        selected_model_id: dry_run.selected_model_id.clone(),
        model_identity_digest: dry_run.model_identity_digest.clone(),
        llama_cli_identity_digest: dry_run.llama_cli_identity_digest.clone(),
        runtime_lane: dry_run.runtime_lane.clone(),
        answer_packet_template_digest: dry_run.answer_packet_template_digest.clone(),
        visible_model_identity_digest: policy_digest(
            "visible-model-identity",
            &[&dry_run.selected_model_id, &dry_run.model_identity_digest],
        ),
        visible_runtime_lane_digest: policy_digest("visible-runtime-lane", &[&dry_run.runtime_lane]),
        visible_route_status_digest: policy_digest(
            "visible-route-status",
            &["packet-materialized-route-not-emitted"],
        ),
        visible_route_caveat_digest: policy_digest(
            "visible-route-caveat",
            &["not-user-facing-not-default-no-quality-claim"],
        ),
        visible_budget_summary_digest: dry_run.budget_vector_digest.clone(),
        visible_memory_headroom_digest: dry_run.memory_headroom_digest.clone(),
        visible_kv_budget_digest: dry_run.kv_budget_digest.clone(),
        visible_latency_budget_digest: dry_run.latency_budget_digest.clone(),
        visible_privacy_class_digest: dry_run.privacy_class_digest.clone(),
        visible_mas_pro_boundary_digest: dry_run.mas_pro_boundary_digest.clone(),
        visible_scope_rex_digest: dry_run.scope_rex_verdict_digest.clone(),
        visible_sovereign_gate_digest: dry_run.sovereign_gate_verdict_digest.clone(),
        visible_fallback_digest: dry_run.fallback_route_digest.clone(),
        visible_abstention_digest: dry_run.abstention_policy_digest.clone(),
        visible_cancellation_digest: dry_run.cancellation_policy_digest.clone(),
        visible_rollback_ref:
            "rollback:gemma-first-runtime-route-answer-packet-visibility-v1".to_string(),
        visible_run_event_log_ref:
            "run_event_log:gemma-first-runtime-route-answer-packet-visibility-v1".to_string(),
        visible_no_default_model_mutation_digest: dry_run.no_default_model_mutation_digest.clone(),
        visible_no_hidden_authority_digest: dry_run.no_hidden_authority_digest.clone(),
        visible_non_promotion_digest: dry_run.non_promotion_digest.clone(),
        settings_surface_copy_digest: policy_digest(
            "settings-surface-copy",
            &["gemma-proof-lane-visible-contract-only"],
        ),
        diagnostics_surface_copy_digest: policy_digest(
            "diagnostics-surface-copy",
            &["gemma-proof-lane-visibility-digest-only"],
        ),
        route_explanation_digest: dry_run.route_explanation_digest.clone(),
        rejected_candidate_summary_digest: policy_digest(
            "rejected-candidate-summary",
            &["none-rejected-in-this-materializer-no-live-route"],
        ),
        user_action_required_digest: policy_digest(
            "user-action-required",
            &["owner-receipt-runtime-quality-release-audit-before-product-use"],
        ),
        no_quality_claim_digest: policy_digest("no-quality-claim", &["quality-not-product-proven"]),
        no_live_default_claim_digest: policy_digest(
            "no-live-default-claim",
            &["gemma-not-default-not-live-route"],
        ),
        no_large_model_bypass_digest: policy_digest(
            "no-large-model-bypass",
            &["e4b-12b-70b-code-assembly-preserved-not-bypassed"],
        ),
        upstream_dry_run_route_packet_ready: dry_run.route_answer_packet_visibility_ready,
        visibility_packet_materialized_count: 1,
        settings_diagnostics_wrv_ready: true,
        future_visibility_packet_present: false,
        future_visibility_packet_bytes_read: 0,
        answer_packet_emitted_to_user_count: 0,
        system_g_dry_run_performed_count: 0,
        admission_performed_count: 0,
        route_priority_mutation_count: 0,
        runtime_router_mutation_count: 0,
        system_g_mutation_count: 0,
        default_model_mutation_count: 0,
        command_armed_count: 0,
        command_executed_count: 0,
        process_spawned_count: 0,
        runtime_replay_performed_count: 0,
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
        quality_claim: false,
        live_gemma_claim: false,
        l2_l3_t4_claim: false,
        live_dense_70b_claim: false,
        ssd_as_ram_claim: false,
        reviewer_visible_summary: "Gemma first-runtime route visibility packet was materialized as digest-only evidence; no user-visible AnswerPacket was emitted and no route/default changed."
            .to_string(),
        metadata_bytes: 176 * 1024,
        next_cursor: GEMMA_FIRST_RUNTIME_ROUTE_ANSWER_PACKET_VISIBILITY_NEXT_CURSOR.to_string(),
        visibility_packet_digest: String::new(),
    };
    packet.visibility_packet_digest = first_runtime_route_answer_packet_visibility_digest(&packet)?;
    validate_first_runtime_route_answer_packet_visibility(&packet)?;
    Ok(packet)
}

pub fn validate_first_runtime_route_answer_packet_visibility(
    packet: &GemmaFirstRuntimeRouteAnswerPacketVisibilityPacket,
) -> Result<(), GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError> {
    if packet.schema_version != GEMMA_FIRST_RUNTIME_ROUTE_ANSWER_PACKET_VISIBILITY_SCHEMA_VERSION {
        return Err(
            GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError::PacketInvalid(
                "schema_version",
            ),
        );
    }
    if packet.route_answer_packet_visibility_gate_id
        != GEMMA_FIRST_RUNTIME_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_ID
        || packet.runtime_lane != "gemma-direct-harness-llama-cpp-gguf-pro-gated"
    {
        return Err(
            GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError::PacketInvalid(
                "runtime_lane",
            ),
        );
    }
    for (field, value) in [
        (
            "upstream_dry_run_route_packet_digest",
            &packet.upstream_dry_run_route_packet_digest,
        ),
        ("model_identity_digest", &packet.model_identity_digest),
        (
            "llama_cli_identity_digest",
            &packet.llama_cli_identity_digest,
        ),
        (
            "answer_packet_template_digest",
            &packet.answer_packet_template_digest,
        ),
        (
            "visible_model_identity_digest",
            &packet.visible_model_identity_digest,
        ),
        (
            "visible_runtime_lane_digest",
            &packet.visible_runtime_lane_digest,
        ),
        (
            "visible_route_status_digest",
            &packet.visible_route_status_digest,
        ),
        (
            "visible_route_caveat_digest",
            &packet.visible_route_caveat_digest,
        ),
        (
            "visible_budget_summary_digest",
            &packet.visible_budget_summary_digest,
        ),
        (
            "visible_memory_headroom_digest",
            &packet.visible_memory_headroom_digest,
        ),
        ("visible_kv_budget_digest", &packet.visible_kv_budget_digest),
        (
            "visible_latency_budget_digest",
            &packet.visible_latency_budget_digest,
        ),
        (
            "visible_privacy_class_digest",
            &packet.visible_privacy_class_digest,
        ),
        (
            "visible_mas_pro_boundary_digest",
            &packet.visible_mas_pro_boundary_digest,
        ),
        ("visible_scope_rex_digest", &packet.visible_scope_rex_digest),
        (
            "visible_sovereign_gate_digest",
            &packet.visible_sovereign_gate_digest,
        ),
        ("visible_fallback_digest", &packet.visible_fallback_digest),
        (
            "visible_abstention_digest",
            &packet.visible_abstention_digest,
        ),
        (
            "visible_cancellation_digest",
            &packet.visible_cancellation_digest,
        ),
        (
            "visible_no_default_model_mutation_digest",
            &packet.visible_no_default_model_mutation_digest,
        ),
        (
            "visible_no_hidden_authority_digest",
            &packet.visible_no_hidden_authority_digest,
        ),
        (
            "visible_non_promotion_digest",
            &packet.visible_non_promotion_digest,
        ),
        (
            "settings_surface_copy_digest",
            &packet.settings_surface_copy_digest,
        ),
        (
            "diagnostics_surface_copy_digest",
            &packet.diagnostics_surface_copy_digest,
        ),
        ("route_explanation_digest", &packet.route_explanation_digest),
        (
            "rejected_candidate_summary_digest",
            &packet.rejected_candidate_summary_digest,
        ),
        (
            "user_action_required_digest",
            &packet.user_action_required_digest,
        ),
        ("no_quality_claim_digest", &packet.no_quality_claim_digest),
        (
            "no_live_default_claim_digest",
            &packet.no_live_default_claim_digest,
        ),
        (
            "no_large_model_bypass_digest",
            &packet.no_large_model_bypass_digest,
        ),
        ("visibility_packet_digest", &packet.visibility_packet_digest),
    ] {
        if !value.starts_with("sha256:") {
            return Err(
                GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError::PacketInvalid(field),
            );
        }
    }
    for (field, value) in [
        ("visible_rollback_ref", &packet.visible_rollback_ref),
        (
            "visible_run_event_log_ref",
            &packet.visible_run_event_log_ref,
        ),
    ] {
        let prefix = if field == "visible_rollback_ref" {
            "rollback:"
        } else {
            "run_event_log:"
        };
        if !value.starts_with(prefix) {
            return Err(
                GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError::PacketInvalid(field),
            );
        }
    }
    if !packet.upstream_dry_run_route_packet_ready
        || packet.visibility_packet_materialized_count != 1
        || !packet.settings_diagnostics_wrv_ready
        || packet.future_visibility_packet_present
        || packet.future_visibility_packet_bytes_read != 0
        || packet.answer_packet_emitted_to_user_count != 0
        || packet.system_g_dry_run_performed_count != 0
        || packet.admission_performed_count != 0
        || packet.route_priority_mutation_count != 0
        || packet.runtime_router_mutation_count != 0
        || packet.system_g_mutation_count != 0
        || packet.default_model_mutation_count != 0
        || packet.command_armed_count != 0
        || packet.command_executed_count != 0
        || packet.process_spawned_count != 0
        || packet.runtime_replay_performed_count != 0
        || packet.model_bytes_loaded != 0
        || packet.runtime_bytes_loaded != 0
        || packet.provider_calls_made != 0
        || packet.raw_prompt_bytes_captured != 0
        || packet.raw_output_bytes_captured != 0
        || packet.answer_packet_suppressed
        || packet.hidden_route_authority
        || packet.hidden_eidos_authority
        || packet.hidden_lattice_authority
        || packet.hidden_patternboost_authority
        || packet.hidden_cloud_fallback
        || packet.quality_claim
        || packet.live_gemma_claim
        || packet.l2_l3_t4_claim
        || packet.live_dense_70b_claim
        || packet.ssd_as_ram_claim
        || packet.metadata_bytes > MAX_VISIBILITY_METADATA_BYTES
        || packet.next_cursor != GEMMA_FIRST_RUNTIME_ROUTE_ANSWER_PACKET_VISIBILITY_NEXT_CURSOR
    {
        return Err(
            GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError::PacketInvalid(
                "policy violation",
            ),
        );
    }
    if packet.visibility_packet_digest
        != first_runtime_route_answer_packet_visibility_digest(packet)?
    {
        return Err(
            GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError::PacketInvalid(
                "visibility_packet_digest",
            ),
        );
    }
    Ok(())
}

pub fn first_runtime_route_answer_packet_visibility_json_pretty(
    packet: &GemmaFirstRuntimeRouteAnswerPacketVisibilityPacket,
) -> Result<Vec<u8>, GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError> {
    validate_first_runtime_route_answer_packet_visibility(packet)?;
    let mut bytes = serde_json::to_vec_pretty(packet)?;
    bytes.push(b'\n');
    Ok(bytes)
}

impl GemmaFirstRuntimeRouteAnswerPacketVisibilityPacket {
    pub fn route_answer_packet_visibility_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_FIRST_RUNTIME_ROUTE_ANSWER_PACKET_VISIBILITY_CURSOR.to_string()),
            self.visibility_packet_digest.as_bytes(),
            created_at_ms,
        )
    }
}

fn first_runtime_route_answer_packet_visibility_digest(
    packet: &GemmaFirstRuntimeRouteAnswerPacketVisibilityPacket,
) -> Result<String, GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError> {
    let mut clone = packet.clone();
    clone.visibility_packet_digest.clear();
    Ok(sha256_hex(&serde_json::to_vec(&clone)?))
}

fn policy_digest(label: &str, parts: &[&str]) -> String {
    sha256_hex(format!("{label}:{}", parts.join("|")).as_bytes())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::falsifier_artifacts::sha256_hex;
    use crate::uas::{
        build_first_runtime_execution_receipt, build_receipt_from_observed_material,
        execute_first_runtime_quality_replay, materialize_first_runtime_quality_packet,
        materialize_first_runtime_runtime_router_admission_packet,
        materialize_first_runtime_system_g_dry_run_route_packet,
        GemmaFirstRuntimeExecutionObservation, GemmaFirstRuntimeExecutionProbeRequest,
        GemmaFirstRuntimeQualityPacketRequest, GemmaFirstRuntimeQualityReplayRequest,
        GemmaFirstRuntimeQualityTaskObservation,
        GemmaFirstRuntimeRuntimeRouterAdmissionPacketRequest,
        GemmaFirstRuntimeSystemGDryRunRoutePacketRequest,
        GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest, GemmaQatQualityTaskFamily,
    };

    fn system_g_packet() -> GemmaFirstRuntimeSystemGDryRunRoutePacket {
        let owner = "owner explicitly approves this local Gemma receipt";
        let owner_receipt = build_receipt_from_observed_material(
            &GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest {
                owner_approval_phrase: owner.to_string(),
                local_file_path: "/Users/jojo/private/gemma-fixture.gguf".into(),
                selected_model_id: "google/gemma-4-E2B-it-qat-q4_0-gguf".to_string(),
                source_repo: "google/gemma-4-E2B-it-qat-q4_0-gguf".to_string(),
                source_revision: "source-card-digest:fixture".to_string(),
                expected_filename: "gemma-fixture.gguf".to_string(),
                expected_byte_count: 12,
                expected_file_sha256: sha256_hex(b"model bytes"),
                source_license_ref: "license:gemma-terms".to_string(),
                provenance_mode: "owner_approved_direct_local_file".to_string(),
                hardware_profile_ref: "hardware:m2-pro-18gb-test".to_string(),
                llama_cli_path: "llama-cli".into(),
            },
            12,
            sha256_hex(b"model bytes"),
            sha256_hex(b"llama-cli version"),
            sha256_hex(b"llama-cli help --offline"),
            true,
            true,
            true,
        )
        .expect("owner receipt");
        let runtime_receipt = build_first_runtime_execution_receipt(
            &GemmaFirstRuntimeExecutionProbeRequest {
                owner_approval_phrase: owner.to_string(),
                upstream_receipt: owner_receipt,
                local_file_path: "/Users/jojo/private/gemma-fixture.gguf".into(),
                llama_cli_path: "llama-cli".into(),
                prompt: "Return exactly OK.".to_string(),
                ctx_size: 512,
                predict: 1,
                seed: 42,
                timeout_ms: 30_000,
            },
            GemmaFirstRuntimeExecutionObservation {
                exit_code: Some(0),
                process_status_success: true,
                timed_out: false,
                duration_ms: 17,
                stdout: b"OK\n".to_vec(),
                stderr: b"timings\n".to_vec(),
                stdout_truncated: false,
                stderr_truncated: false,
            },
        )
        .expect("runtime receipt");
        let quality_packet =
            materialize_first_runtime_quality_packet(&GemmaFirstRuntimeQualityPacketRequest {
                runtime_receipt,
            })
            .expect("quality packet");
        let observations = quality_packet
            .task_packets
            .iter()
            .map(|task| GemmaFirstRuntimeQualityTaskObservation {
                task_family: task.task_family,
                task_descriptor_digest: task.task_descriptor_digest.clone(),
                expected_output_shape_digest: task.expected_output_shape_digest.clone(),
                fixture_prompt_digest: sha256_hex(
                    format!("{:?}:prompt", task.task_family).as_bytes(),
                ),
                candidate_output: passing_candidate(task.task_family).to_string(),
                duration_ms: 25,
                exit_code: 0,
                timed_out: false,
                cache_deleted_before_replay: true,
                contamination_check_passed: true,
            })
            .collect();
        let replay = execute_first_runtime_quality_replay(&GemmaFirstRuntimeQualityReplayRequest {
            observations,
            quality_packet,
        })
        .expect("quality replay");
        let admission = materialize_first_runtime_runtime_router_admission_packet(
            &GemmaFirstRuntimeRuntimeRouterAdmissionPacketRequest {
                quality_replay_artifact: replay,
            },
        )
        .expect("admission packet");
        materialize_first_runtime_system_g_dry_run_route_packet(
            &GemmaFirstRuntimeSystemGDryRunRoutePacketRequest {
                admission_packet: admission,
            },
        )
        .expect("system g packet")
    }

    fn passing_candidate(task_family: GemmaQatQualityTaskFamily) -> &'static str {
        match task_family {
            GemmaQatQualityTaskFamily::NoteSynthesis => {
                "This note synthesis combines the main claim, supporting detail, and next action in a concise form."
            }
            GemmaQatQualityTaskFamily::CitationGroundedResearch => {
                "The answer cites the provided source [A] and distinguishes the verified claim from open uncertainty."
            }
            GemmaQatQualityTaskFamily::StructuredToolJson => {
                "{\"action\":\"summarize\",\"confidence\":0.91}"
            }
            GemmaQatQualityTaskFamily::CacheDeletionReuse => {
                "Cache reuse is denied until the fresh cache deletion and replay lineage are verified."
            }
            GemmaQatQualityTaskFamily::WritingEdit => {
                "The revision keeps the meaning intact while improving clarity, rhythm, and sentence flow."
            }
            GemmaQatQualityTaskFamily::CodingPatch => "```diff\n@@\n- old\n+ new\n```",
            GemmaQatQualityTaskFamily::RefusalAbstention => {
                "I cannot help with that private data request and will abstain unless permission is granted."
            }
        }
    }

    #[test]
    fn materializes_zero_action_visibility_packet() {
        let packet = materialize_first_runtime_route_answer_packet_visibility(
            &GemmaFirstRuntimeRouteAnswerPacketVisibilityRequest {
                system_g_dry_run_packet: system_g_packet(),
            },
        )
        .expect("visibility packet");

        validate_first_runtime_route_answer_packet_visibility(&packet).expect("valid packet");
        assert_eq!(packet.visibility_packet_materialized_count, 1);
        assert_eq!(packet.answer_packet_emitted_to_user_count, 0);
        assert_eq!(packet.system_g_dry_run_performed_count, 0);
        assert_eq!(packet.runtime_router_mutation_count, 0);
        assert!(packet.settings_diagnostics_wrv_ready);
        assert!(!packet.live_gemma_claim);
        assert_eq!(
            packet.next_cursor,
            GEMMA_FIRST_RUNTIME_ROUTE_ANSWER_PACKET_VISIBILITY_NEXT_CURSOR
        );
    }

    #[test]
    fn blocked_dry_run_packet_cannot_create_visibility_packet() {
        let mut dry_run = system_g_packet();
        dry_run.route_answer_packet_visibility_ready = false;
        dry_run.route_packet_digest = "sha256:forced-invalid".to_string();
        let result = materialize_first_runtime_route_answer_packet_visibility(
            &GemmaFirstRuntimeRouteAnswerPacketVisibilityRequest {
                system_g_dry_run_packet: dry_run,
            },
        );
        assert!(result.is_err());
    }

    #[test]
    fn pretty_json_excludes_raw_path_outputs_and_user_packet() {
        let packet = materialize_first_runtime_route_answer_packet_visibility(
            &GemmaFirstRuntimeRouteAnswerPacketVisibilityRequest {
                system_g_dry_run_packet: system_g_packet(),
            },
        )
        .expect("visibility packet");
        let json = String::from_utf8(
            first_runtime_route_answer_packet_visibility_json_pretty(&packet).unwrap(),
        )
        .expect("utf8");

        assert!(json.contains("visibility_packet_digest"));
        assert!(json.contains("settings_diagnostics_wrv_ready"));
        assert!(!json.contains("/Users/jojo/private"));
        assert!(!json.contains("This note synthesis combines"));
        assert!(!json.contains("Return exactly OK."));
    }
}
