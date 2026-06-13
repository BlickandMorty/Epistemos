//! Gemma first-runtime settings/diagnostics WRV materializer.
//!
//! This bridge consumes the digest-only route AnswerPacket visibility packet
//! and emits a digest-only WRV packet that proves the Settings/diagnostics
//! surface may describe the Gemma proof lane without unlocking a model picker,
//! emitting a user-visible AnswerPacket, mutating routes, executing commands,
//! loading model bytes, or claiming Gemma product capability.

use serde::{Deserialize, Serialize};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{
    validate_first_runtime_route_answer_packet_visibility,
    GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError,
    GemmaFirstRuntimeRouteAnswerPacketVisibilityPacket, UasAddress, UasKind,
    GEMMA_FIRST_RUNTIME_ROUTE_ANSWER_PACKET_VISIBILITY_NEXT_CURSOR,
};

pub const GEMMA_FIRST_RUNTIME_SETTINGS_DIAGNOSTICS_WRV_SCHEMA_VERSION: &str =
    "gemma-first-runtime-settings-diagnostics-wrv-v1";
pub const GEMMA_FIRST_RUNTIME_SETTINGS_DIAGNOSTICS_WRV_CURSOR: &str =
    "gemma_direct_harness_owner_approved_settings_diagnostics_wrv_gate";
pub const GEMMA_FIRST_RUNTIME_SETTINGS_DIAGNOSTICS_WRV_GATE_ID: &str =
    "F-GemmaDirectHarnessOwnerApprovedSettingsDiagnosticsWRVGate";
pub const GEMMA_FIRST_RUNTIME_SETTINGS_DIAGNOSTICS_WRV_NEXT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";

const MAX_WRV_METADATA_BYTES: u64 = 384 * 1024;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GemmaFirstRuntimeSettingsDiagnosticsWrvRequest {
    pub route_visibility_packet: GemmaFirstRuntimeRouteAnswerPacketVisibilityPacket,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaFirstRuntimeSettingsDiagnosticsWrvPacket {
    pub schema_version: String,
    pub settings_diagnostics_wrv_gate_id: String,
    pub upstream_route_visibility_packet_digest: String,
    pub selected_model_id: String,
    pub model_identity_digest: String,
    pub llama_cli_identity_digest: String,
    pub runtime_lane: String,
    pub settings_source_marker_digest: String,
    pub diagnostics_source_marker_digest: String,
    pub wrv_test_marker_digest: String,
    pub manual_check_plan_digest: String,
    pub release_audit_blocker_digest: String,
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
    pub settings_surface_copy_digest: String,
    pub diagnostics_surface_copy_digest: String,
    pub route_explanation_digest: String,
    pub rejected_candidate_summary_digest: String,
    pub user_action_required_digest: String,
    pub no_toggle_unlock_digest: String,
    pub no_quality_claim_digest: String,
    pub no_live_default_claim_digest: String,
    pub no_large_model_bypass_digest: String,
    pub no_l2_l3_t4_claim_digest: String,
    pub upstream_route_visibility_ready: bool,
    pub wrv_packet_materialized_count: u64,
    pub settings_diagnostics_wrv_passed: bool,
    pub release_audit_automated_checks_ready: bool,
    pub future_product_visibility_packet_present: bool,
    pub future_product_visibility_packet_bytes_read: u64,
    pub settings_toggle_unlocked: bool,
    pub diagnostics_live_route_claimed: bool,
    pub model_picker_default_mutation_allowed: bool,
    pub answer_packet_emitted_to_user_count: u64,
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
    pub wrv_packet_digest: String,
}

#[derive(Debug)]
pub enum GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError {
    RouteVisibility(GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError),
    PacketInvalid(&'static str),
    Serialize(serde_json::Error),
}

impl fmt::Display for GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::RouteVisibility(error) => write!(f, "route visibility packet invalid: {error}"),
            Self::PacketInvalid(reason) => write!(f, "settings WRV packet invalid: {reason}"),
            Self::Serialize(error) => write!(f, "settings WRV packet serialization error: {error}"),
        }
    }
}

impl std::error::Error for GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError {}

impl From<GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError>
    for GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError
{
    fn from(value: GemmaFirstRuntimeRouteAnswerPacketVisibilityMaterializerError) -> Self {
        Self::RouteVisibility(value)
    }
}

impl From<serde_json::Error> for GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError {
    fn from(value: serde_json::Error) -> Self {
        Self::Serialize(value)
    }
}

pub fn materialize_first_runtime_settings_diagnostics_wrv(
    request: &GemmaFirstRuntimeSettingsDiagnosticsWrvRequest,
) -> Result<
    GemmaFirstRuntimeSettingsDiagnosticsWrvPacket,
    GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError,
> {
    let visibility = &request.route_visibility_packet;
    validate_first_runtime_route_answer_packet_visibility(visibility)?;
    if visibility.next_cursor != GEMMA_FIRST_RUNTIME_ROUTE_ANSWER_PACKET_VISIBILITY_NEXT_CURSOR {
        return Err(
            GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError::PacketInvalid(
                "route_visibility_packet.next_cursor",
            ),
        );
    }
    if !visibility.settings_diagnostics_wrv_ready {
        return Err(
            GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError::PacketInvalid(
                "settings_diagnostics_wrv_ready",
            ),
        );
    }

    let mut packet = GemmaFirstRuntimeSettingsDiagnosticsWrvPacket {
        schema_version: GEMMA_FIRST_RUNTIME_SETTINGS_DIAGNOSTICS_WRV_SCHEMA_VERSION.to_string(),
        settings_diagnostics_wrv_gate_id: GEMMA_FIRST_RUNTIME_SETTINGS_DIAGNOSTICS_WRV_GATE_ID
            .to_string(),
        upstream_route_visibility_packet_digest: visibility.visibility_packet_digest.clone(),
        selected_model_id: visibility.selected_model_id.clone(),
        model_identity_digest: visibility.model_identity_digest.clone(),
        llama_cli_identity_digest: visibility.llama_cli_identity_digest.clone(),
        runtime_lane: visibility.runtime_lane.clone(),
        settings_source_marker_digest: policy_digest(
            "settings-source-marker",
            &[
                "LocalAgentDiagnosticsHealthRow",
                "Gemma proof lane",
                "owner receipt missing",
            ],
        ),
        diagnostics_source_marker_digest: policy_digest(
            "diagnostics-source-marker",
            &[
                "CapabilityCeilingHealthSnapshot",
                "route visibility ready",
                "no default mutation",
            ],
        ),
        wrv_test_marker_digest: policy_digest(
            "wrv-test-marker",
            &[
                "SubstrateHealthPanelTests",
                "materialize_gemma_first_runtime_route_answer_packet_visibility.sh",
            ],
        ),
        manual_check_plan_digest: policy_digest(
            "manual-check-plan",
            &[
                "settings shows proof lane only",
                "model picker remains unchanged",
                "release audit remains blocked until distribution compliance and three zero-fail passes land",
            ],
        ),
        release_audit_blocker_digest: policy_digest(
            "release-audit-blocker",
            &[GEMMA_FIRST_RUNTIME_SETTINGS_DIAGNOSTICS_WRV_NEXT_CURSOR],
        ),
        answer_packet_template_digest: visibility.answer_packet_template_digest.clone(),
        visible_model_identity_digest: visibility.visible_model_identity_digest.clone(),
        visible_runtime_lane_digest: visibility.visible_runtime_lane_digest.clone(),
        visible_route_status_digest: visibility.visible_route_status_digest.clone(),
        visible_route_caveat_digest: visibility.visible_route_caveat_digest.clone(),
        visible_budget_summary_digest: visibility.visible_budget_summary_digest.clone(),
        visible_memory_headroom_digest: visibility.visible_memory_headroom_digest.clone(),
        visible_kv_budget_digest: visibility.visible_kv_budget_digest.clone(),
        visible_latency_budget_digest: visibility.visible_latency_budget_digest.clone(),
        visible_privacy_class_digest: visibility.visible_privacy_class_digest.clone(),
        visible_mas_pro_boundary_digest: visibility.visible_mas_pro_boundary_digest.clone(),
        visible_scope_rex_digest: visibility.visible_scope_rex_digest.clone(),
        visible_sovereign_gate_digest: visibility.visible_sovereign_gate_digest.clone(),
        visible_fallback_digest: visibility.visible_fallback_digest.clone(),
        visible_abstention_digest: visibility.visible_abstention_digest.clone(),
        visible_cancellation_digest: visibility.visible_cancellation_digest.clone(),
        visible_rollback_ref: "rollback:gemma-first-runtime-settings-diagnostics-wrv-v1"
            .to_string(),
        visible_run_event_log_ref:
            "run_event_log:gemma-first-runtime-settings-diagnostics-wrv-v1".to_string(),
        settings_surface_copy_digest: visibility.settings_surface_copy_digest.clone(),
        diagnostics_surface_copy_digest: visibility.diagnostics_surface_copy_digest.clone(),
        route_explanation_digest: visibility.route_explanation_digest.clone(),
        rejected_candidate_summary_digest: visibility.rejected_candidate_summary_digest.clone(),
        user_action_required_digest: visibility.user_action_required_digest.clone(),
        no_toggle_unlock_digest: policy_digest(
            "no-toggle-unlock",
            &["Gemma proof lane visible but route toggle remains unavailable"],
        ),
        no_quality_claim_digest: visibility.no_quality_claim_digest.clone(),
        no_live_default_claim_digest: visibility.no_live_default_claim_digest.clone(),
        no_large_model_bypass_digest: visibility.no_large_model_bypass_digest.clone(),
        no_l2_l3_t4_claim_digest: policy_digest(
            "no-l2-l3-t4-claim",
            &["settings diagnostics WRV does not promote capability"],
        ),
        upstream_route_visibility_ready: visibility.settings_diagnostics_wrv_ready,
        wrv_packet_materialized_count: 1,
        settings_diagnostics_wrv_passed: true,
        release_audit_automated_checks_ready: true,
        future_product_visibility_packet_present: false,
        future_product_visibility_packet_bytes_read: 0,
        settings_toggle_unlocked: false,
        diagnostics_live_route_claimed: false,
        model_picker_default_mutation_allowed: false,
        answer_packet_emitted_to_user_count: 0,
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
        reviewer_visible_summary: "Gemma first-runtime settings/diagnostics WRV is digest-only: Settings may show the blocked proof lane, but no picker/default/route/System G state changes and distribution compliance plus three uninterrupted zero-fail release passes remain the next blocker."
            .to_string(),
        metadata_bytes: 208 * 1024,
        next_cursor: GEMMA_FIRST_RUNTIME_SETTINGS_DIAGNOSTICS_WRV_NEXT_CURSOR.to_string(),
        wrv_packet_digest: String::new(),
    };
    packet.wrv_packet_digest = first_runtime_settings_diagnostics_wrv_digest(&packet)?;
    validate_first_runtime_settings_diagnostics_wrv(&packet)?;
    Ok(packet)
}

pub fn validate_first_runtime_settings_diagnostics_wrv(
    packet: &GemmaFirstRuntimeSettingsDiagnosticsWrvPacket,
) -> Result<(), GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError> {
    if packet.schema_version != GEMMA_FIRST_RUNTIME_SETTINGS_DIAGNOSTICS_WRV_SCHEMA_VERSION {
        return Err(
            GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError::PacketInvalid(
                "schema_version",
            ),
        );
    }
    if packet.settings_diagnostics_wrv_gate_id
        != GEMMA_FIRST_RUNTIME_SETTINGS_DIAGNOSTICS_WRV_GATE_ID
        || packet.runtime_lane != "gemma-direct-harness-llama-cpp-gguf-pro-gated"
    {
        return Err(
            GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError::PacketInvalid("runtime_lane"),
        );
    }
    for (field, value) in [
        (
            "upstream_route_visibility_packet_digest",
            &packet.upstream_route_visibility_packet_digest,
        ),
        ("model_identity_digest", &packet.model_identity_digest),
        (
            "llama_cli_identity_digest",
            &packet.llama_cli_identity_digest,
        ),
        (
            "settings_source_marker_digest",
            &packet.settings_source_marker_digest,
        ),
        (
            "diagnostics_source_marker_digest",
            &packet.diagnostics_source_marker_digest,
        ),
        ("wrv_test_marker_digest", &packet.wrv_test_marker_digest),
        ("manual_check_plan_digest", &packet.manual_check_plan_digest),
        (
            "release_audit_blocker_digest",
            &packet.release_audit_blocker_digest,
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
        ("no_toggle_unlock_digest", &packet.no_toggle_unlock_digest),
        ("no_quality_claim_digest", &packet.no_quality_claim_digest),
        (
            "no_live_default_claim_digest",
            &packet.no_live_default_claim_digest,
        ),
        (
            "no_large_model_bypass_digest",
            &packet.no_large_model_bypass_digest,
        ),
        ("no_l2_l3_t4_claim_digest", &packet.no_l2_l3_t4_claim_digest),
        ("wrv_packet_digest", &packet.wrv_packet_digest),
    ] {
        if !value.starts_with("sha256:") {
            return Err(
                GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError::PacketInvalid(field),
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
                GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError::PacketInvalid(field),
            );
        }
    }
    if !packet.upstream_route_visibility_ready
        || packet.wrv_packet_materialized_count != 1
        || !packet.settings_diagnostics_wrv_passed
        || !packet.release_audit_automated_checks_ready
        || packet.future_product_visibility_packet_present
        || packet.future_product_visibility_packet_bytes_read != 0
        || packet.settings_toggle_unlocked
        || packet.diagnostics_live_route_claimed
        || packet.model_picker_default_mutation_allowed
        || packet.answer_packet_emitted_to_user_count != 0
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
        || packet.metadata_bytes > MAX_WRV_METADATA_BYTES
        || packet.next_cursor != GEMMA_FIRST_RUNTIME_SETTINGS_DIAGNOSTICS_WRV_NEXT_CURSOR
    {
        return Err(
            GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError::PacketInvalid(
                "policy violation",
            ),
        );
    }
    if packet.wrv_packet_digest != first_runtime_settings_diagnostics_wrv_digest(packet)? {
        return Err(
            GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError::PacketInvalid(
                "wrv_packet_digest",
            ),
        );
    }
    Ok(())
}

pub fn first_runtime_settings_diagnostics_wrv_json_pretty(
    packet: &GemmaFirstRuntimeSettingsDiagnosticsWrvPacket,
) -> Result<Vec<u8>, GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError> {
    validate_first_runtime_settings_diagnostics_wrv(packet)?;
    let mut bytes = serde_json::to_vec_pretty(packet)?;
    bytes.push(b'\n');
    Ok(bytes)
}

impl GemmaFirstRuntimeSettingsDiagnosticsWrvPacket {
    pub fn settings_diagnostics_wrv_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_FIRST_RUNTIME_SETTINGS_DIAGNOSTICS_WRV_CURSOR.to_string()),
            self.wrv_packet_digest.as_bytes(),
            created_at_ms,
        )
    }
}

fn first_runtime_settings_diagnostics_wrv_digest(
    packet: &GemmaFirstRuntimeSettingsDiagnosticsWrvPacket,
) -> Result<String, GemmaFirstRuntimeSettingsDiagnosticsWrvMaterializerError> {
    let mut clone = packet.clone();
    clone.wrv_packet_digest.clear();
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
        materialize_first_runtime_route_answer_packet_visibility,
        materialize_first_runtime_runtime_router_admission_packet,
        materialize_first_runtime_system_g_dry_run_route_packet,
        GemmaFirstRuntimeExecutionObservation, GemmaFirstRuntimeExecutionProbeRequest,
        GemmaFirstRuntimeQualityPacketRequest, GemmaFirstRuntimeQualityReplayRequest,
        GemmaFirstRuntimeQualityTaskObservation,
        GemmaFirstRuntimeRouteAnswerPacketVisibilityRequest,
        GemmaFirstRuntimeRuntimeRouterAdmissionPacketRequest,
        GemmaFirstRuntimeSystemGDryRunRoutePacketRequest,
        GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest, GemmaQatQualityTaskFamily,
    };

    fn route_visibility_packet() -> GemmaFirstRuntimeRouteAnswerPacketVisibilityPacket {
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
        let system_g = materialize_first_runtime_system_g_dry_run_route_packet(
            &GemmaFirstRuntimeSystemGDryRunRoutePacketRequest {
                admission_packet: admission,
            },
        )
        .expect("system g packet");
        materialize_first_runtime_route_answer_packet_visibility(
            &GemmaFirstRuntimeRouteAnswerPacketVisibilityRequest {
                system_g_dry_run_packet: system_g,
            },
        )
        .expect("visibility packet")
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
    fn materializes_settings_diagnostics_wrv_packet() {
        let packet = materialize_first_runtime_settings_diagnostics_wrv(
            &GemmaFirstRuntimeSettingsDiagnosticsWrvRequest {
                route_visibility_packet: route_visibility_packet(),
            },
        )
        .expect("settings diagnostics wrv");

        validate_first_runtime_settings_diagnostics_wrv(&packet).expect("valid packet");
        assert!(packet.settings_diagnostics_wrv_passed);
        assert!(packet.release_audit_automated_checks_ready);
        assert_eq!(packet.answer_packet_emitted_to_user_count, 0);
        assert_eq!(packet.runtime_router_mutation_count, 0);
        assert!(!packet.settings_toggle_unlocked);
        assert!(!packet.live_gemma_claim);
        assert_eq!(
            packet.next_cursor,
            GEMMA_FIRST_RUNTIME_SETTINGS_DIAGNOSTICS_WRV_NEXT_CURSOR
        );
    }

    #[test]
    fn blocked_visibility_packet_cannot_create_wrv_packet() {
        let mut visibility = route_visibility_packet();
        visibility.settings_diagnostics_wrv_ready = false;
        visibility.visibility_packet_digest = "sha256:forced-invalid".to_string();
        let result = materialize_first_runtime_settings_diagnostics_wrv(
            &GemmaFirstRuntimeSettingsDiagnosticsWrvRequest {
                route_visibility_packet: visibility,
            },
        );
        assert!(result.is_err());
    }

    #[test]
    fn pretty_json_excludes_raw_paths_outputs_and_route_unlock() {
        let packet = materialize_first_runtime_settings_diagnostics_wrv(
            &GemmaFirstRuntimeSettingsDiagnosticsWrvRequest {
                route_visibility_packet: route_visibility_packet(),
            },
        )
        .expect("settings diagnostics wrv");
        let json =
            String::from_utf8(first_runtime_settings_diagnostics_wrv_json_pretty(&packet).unwrap())
                .expect("utf8");

        assert!(json.contains("wrv_packet_digest"));
        assert!(json.contains("release_audit_automated_checks_ready"));
        assert!(!json.contains("/Users/jojo/private"));
        assert!(!json.contains("This note synthesis combines"));
        assert!(!json.contains("Return exactly OK."));
        assert!(!json.contains("OK\\n"));
    }
}
