//! Gemma first-runtime System G dry-run route packet materializer.
//!
//! This bridge consumes the digest-only RuntimeRouter admission packet and
//! emits the first System G dry-run route packet artifact. It still does not
//! perform admission, mutate route priority, execute System G, load model
//! bytes, retain raw prompt/output, or claim product capability.

use serde::{Deserialize, Serialize};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{
    validate_first_runtime_runtime_router_admission_packet,
    GemmaFirstRuntimeRuntimeRouterAdmissionPacket,
    GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError, UasAddress, UasKind,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_NEXT_CURSOR,
};

pub const GEMMA_FIRST_RUNTIME_SYSTEM_G_DRY_RUN_ROUTE_PACKET_SCHEMA_VERSION: &str =
    "gemma-first-runtime-system-g-dry-run-route-packet-v1";
pub const GEMMA_FIRST_RUNTIME_SYSTEM_G_DRY_RUN_ROUTE_PACKET_CURSOR: &str =
    "gemma_direct_harness_owner_approved_system_g_dry_run_route_packet_gate";
pub const GEMMA_FIRST_RUNTIME_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_ID: &str =
    "F-GemmaDirectHarnessOwnerApprovedSystemGDryRunRoutePacketGate";
pub const GEMMA_FIRST_RUNTIME_SYSTEM_G_DRY_RUN_ROUTE_PACKET_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_route_answer_packet_visibility_gate";

const MAX_DRY_RUN_METADATA_BYTES: u64 = 384 * 1024;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GemmaFirstRuntimeSystemGDryRunRoutePacketRequest {
    pub admission_packet: GemmaFirstRuntimeRuntimeRouterAdmissionPacket,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaFirstRuntimeSystemGDryRunRoutePacket {
    pub schema_version: String,
    pub system_g_dry_run_gate_id: String,
    pub upstream_admission_packet_digest: String,
    pub selected_model_id: String,
    pub model_identity_digest: String,
    pub llama_cli_identity_digest: String,
    pub runtime_lane: String,
    pub system_g_dry_run_envelope_digest: String,
    pub runtime_router_policy_digest: String,
    pub route_priority_snapshot_digest: String,
    pub no_priority_mutation_digest: String,
    pub budget_vector_digest: String,
    pub memory_headroom_digest: String,
    pub kv_budget_digest: String,
    pub latency_budget_digest: String,
    pub privacy_class_digest: String,
    pub mas_pro_boundary_digest: String,
    pub scope_rex_verdict_digest: String,
    pub sovereign_gate_verdict_digest: String,
    pub fallback_route_digest: String,
    pub abstention_policy_digest: String,
    pub cancellation_policy_digest: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub visible_caveat_digest: String,
    pub settings_visibility_digest: String,
    pub diagnostic_visibility_digest: String,
    pub route_explanation_digest: String,
    pub mission_packet_template_digest: String,
    pub run_event_log_template_digest: String,
    pub answer_packet_template_digest: String,
    pub no_default_model_mutation_digest: String,
    pub no_hidden_authority_digest: String,
    pub non_promotion_digest: String,
    pub upstream_admission_packet_ready: bool,
    pub system_g_dry_run_packet_materialized_count: u64,
    pub route_answer_packet_visibility_ready: bool,
    pub future_route_packet_present: bool,
    pub future_route_packet_bytes_read: u64,
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
    pub route_packet_digest: String,
}

#[derive(Debug)]
pub enum GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError {
    Admission(GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError),
    PacketInvalid(&'static str),
    Serialize(serde_json::Error),
}

impl fmt::Display for GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Admission(error) => write!(f, "admission packet invalid: {error}"),
            Self::PacketInvalid(reason) => write!(f, "System G dry-run packet invalid: {reason}"),
            Self::Serialize(error) => write!(f, "System G dry-run serialization error: {error}"),
        }
    }
}

impl std::error::Error for GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError {}

impl From<GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError>
    for GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError
{
    fn from(value: GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError) -> Self {
        Self::Admission(value)
    }
}

impl From<serde_json::Error> for GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError {
    fn from(value: serde_json::Error) -> Self {
        Self::Serialize(value)
    }
}

pub fn materialize_first_runtime_system_g_dry_run_route_packet(
    request: &GemmaFirstRuntimeSystemGDryRunRoutePacketRequest,
) -> Result<
    GemmaFirstRuntimeSystemGDryRunRoutePacket,
    GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError,
> {
    let admission = &request.admission_packet;
    validate_first_runtime_runtime_router_admission_packet(admission)?;
    if admission.next_cursor
        != GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_NEXT_CURSOR
    {
        return Err(
            GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError::PacketInvalid(
                "admission_packet.next_cursor",
            ),
        );
    }
    if !admission.system_g_dry_run_packet_ready {
        return Err(
            GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError::PacketInvalid(
                "system_g_dry_run_packet_ready",
            ),
        );
    }

    let mut packet = GemmaFirstRuntimeSystemGDryRunRoutePacket {
        schema_version: GEMMA_FIRST_RUNTIME_SYSTEM_G_DRY_RUN_ROUTE_PACKET_SCHEMA_VERSION
            .to_string(),
        system_g_dry_run_gate_id: GEMMA_FIRST_RUNTIME_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_ID
            .to_string(),
        upstream_admission_packet_digest: admission.admission_packet_digest.clone(),
        selected_model_id: admission.selected_model_id.clone(),
        model_identity_digest: admission.model_identity_digest.clone(),
        llama_cli_identity_digest: admission.llama_cli_identity_digest.clone(),
        runtime_lane: admission.runtime_lane.clone(),
        system_g_dry_run_envelope_digest: policy_digest(
            "system-g-dry-run-envelope",
            &[&admission.admission_packet_digest, "packet-only-no-run"],
        ),
        runtime_router_policy_digest: policy_digest(
            "runtime-router-policy",
            &[&admission.route_priority_snapshot_digest, "evaluate-no-mutate"],
        ),
        route_priority_snapshot_digest: admission.route_priority_snapshot_digest.clone(),
        no_priority_mutation_digest: policy_digest(
            "no-priority-mutation",
            &[&admission.route_priority_snapshot_digest],
        ),
        budget_vector_digest: admission.budget_vector_digest.clone(),
        memory_headroom_digest: admission.memory_headroom_digest.clone(),
        kv_budget_digest: admission.kv_budget_digest.clone(),
        latency_budget_digest: admission.latency_budget_digest.clone(),
        privacy_class_digest: admission.privacy_class_digest.clone(),
        mas_pro_boundary_digest: admission.mas_pro_boundary_digest.clone(),
        scope_rex_verdict_digest: admission.scope_rex_verdict_digest.clone(),
        sovereign_gate_verdict_digest: admission.sovereign_gate_verdict_digest.clone(),
        fallback_route_digest: admission.fallback_route_digest.clone(),
        abstention_policy_digest: admission.abstention_policy_digest.clone(),
        cancellation_policy_digest: admission.cancellation_policy_digest.clone(),
        rollback_ref: "rollback:gemma-first-runtime-system-g-dry-run-route-packet-v1"
            .to_string(),
        run_event_log_ref: "run_event_log:gemma-first-runtime-system-g-dry-run-route-packet-v1"
            .to_string(),
        answer_packet_ref: "answer_packet:gemma-first-runtime-system-g-dry-run-route-packet-v1"
            .to_string(),
        visible_caveat_digest: policy_digest(
            "visible-caveat",
            &["system-g-dry-run-packet-materialized-not-user-facing"],
        ),
        settings_visibility_digest: policy_digest(
            "settings-visibility",
            &["gemma-proof-lane-system-g-dry-run-packet-visible"],
        ),
        diagnostic_visibility_digest: policy_digest(
            "diagnostic-visibility",
            &["gemma-proof-lane-system-g-dry-run-packet-digest-only"],
        ),
        route_explanation_digest: policy_digest(
            "route-explanation",
            &[&admission.selected_model_id, "dry-run-route-not-emitted"],
        ),
        mission_packet_template_digest: policy_digest(
            "mission-packet-template",
            &[&admission.selected_model_id, "template-only"],
        ),
        run_event_log_template_digest: policy_digest(
            "run-event-log-template",
            &[&admission.run_event_log_ref, "template-only"],
        ),
        answer_packet_template_digest: policy_digest(
            "answer-packet-template",
            &[&admission.answer_packet_ref, "template-only"],
        ),
        no_default_model_mutation_digest: admission.no_default_model_mutation_digest.clone(),
        no_hidden_authority_digest: admission.no_hidden_authority_digest.clone(),
        non_promotion_digest: admission.non_promotion_digest.clone(),
        upstream_admission_packet_ready: admission.runtime_router_admission_packet_ready,
        system_g_dry_run_packet_materialized_count: 1,
        route_answer_packet_visibility_ready: true,
        future_route_packet_present: false,
        future_route_packet_bytes_read: 0,
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
        reviewer_visible_summary: "Gemma first-runtime System G dry-run packet was materialized as digest-only route evidence; no System G route was emitted and no app default changed."
            .to_string(),
        metadata_bytes: 160 * 1024,
        next_cursor: GEMMA_FIRST_RUNTIME_SYSTEM_G_DRY_RUN_ROUTE_PACKET_NEXT_CURSOR.to_string(),
        route_packet_digest: String::new(),
    };
    packet.route_packet_digest = first_runtime_system_g_dry_run_route_packet_digest(&packet)?;
    validate_first_runtime_system_g_dry_run_route_packet(&packet)?;
    Ok(packet)
}

pub fn validate_first_runtime_system_g_dry_run_route_packet(
    packet: &GemmaFirstRuntimeSystemGDryRunRoutePacket,
) -> Result<(), GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError> {
    if packet.schema_version != GEMMA_FIRST_RUNTIME_SYSTEM_G_DRY_RUN_ROUTE_PACKET_SCHEMA_VERSION {
        return Err(
            GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError::PacketInvalid(
                "schema_version",
            ),
        );
    }
    if packet.system_g_dry_run_gate_id != GEMMA_FIRST_RUNTIME_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_ID
        || packet.runtime_lane != "gemma-direct-harness-llama-cpp-gguf-pro-gated"
    {
        return Err(
            GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError::PacketInvalid(
                "runtime_lane",
            ),
        );
    }
    for (field, value) in [
        (
            "upstream_admission_packet_digest",
            &packet.upstream_admission_packet_digest,
        ),
        ("model_identity_digest", &packet.model_identity_digest),
        (
            "llama_cli_identity_digest",
            &packet.llama_cli_identity_digest,
        ),
        (
            "system_g_dry_run_envelope_digest",
            &packet.system_g_dry_run_envelope_digest,
        ),
        (
            "runtime_router_policy_digest",
            &packet.runtime_router_policy_digest,
        ),
        (
            "route_priority_snapshot_digest",
            &packet.route_priority_snapshot_digest,
        ),
        (
            "no_priority_mutation_digest",
            &packet.no_priority_mutation_digest,
        ),
        ("budget_vector_digest", &packet.budget_vector_digest),
        ("memory_headroom_digest", &packet.memory_headroom_digest),
        ("kv_budget_digest", &packet.kv_budget_digest),
        ("latency_budget_digest", &packet.latency_budget_digest),
        ("privacy_class_digest", &packet.privacy_class_digest),
        ("mas_pro_boundary_digest", &packet.mas_pro_boundary_digest),
        ("scope_rex_verdict_digest", &packet.scope_rex_verdict_digest),
        (
            "sovereign_gate_verdict_digest",
            &packet.sovereign_gate_verdict_digest,
        ),
        ("fallback_route_digest", &packet.fallback_route_digest),
        ("abstention_policy_digest", &packet.abstention_policy_digest),
        (
            "cancellation_policy_digest",
            &packet.cancellation_policy_digest,
        ),
        ("visible_caveat_digest", &packet.visible_caveat_digest),
        (
            "settings_visibility_digest",
            &packet.settings_visibility_digest,
        ),
        (
            "diagnostic_visibility_digest",
            &packet.diagnostic_visibility_digest,
        ),
        ("route_explanation_digest", &packet.route_explanation_digest),
        (
            "mission_packet_template_digest",
            &packet.mission_packet_template_digest,
        ),
        (
            "run_event_log_template_digest",
            &packet.run_event_log_template_digest,
        ),
        (
            "answer_packet_template_digest",
            &packet.answer_packet_template_digest,
        ),
        (
            "no_default_model_mutation_digest",
            &packet.no_default_model_mutation_digest,
        ),
        (
            "no_hidden_authority_digest",
            &packet.no_hidden_authority_digest,
        ),
        ("non_promotion_digest", &packet.non_promotion_digest),
        ("route_packet_digest", &packet.route_packet_digest),
    ] {
        if !value.starts_with("sha256:") {
            return Err(
                GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError::PacketInvalid(field),
            );
        }
    }
    for (field, value) in [
        ("rollback_ref", &packet.rollback_ref),
        ("run_event_log_ref", &packet.run_event_log_ref),
        ("answer_packet_ref", &packet.answer_packet_ref),
    ] {
        let prefix = match field {
            "rollback_ref" => "rollback:",
            "run_event_log_ref" => "run_event_log:",
            _ => "answer_packet:",
        };
        if !value.starts_with(prefix) {
            return Err(
                GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError::PacketInvalid(field),
            );
        }
    }
    if !packet.upstream_admission_packet_ready
        || packet.system_g_dry_run_packet_materialized_count != 1
        || !packet.route_answer_packet_visibility_ready
        || packet.future_route_packet_present
        || packet.future_route_packet_bytes_read != 0
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
        || packet.metadata_bytes > MAX_DRY_RUN_METADATA_BYTES
        || packet.next_cursor != GEMMA_FIRST_RUNTIME_SYSTEM_G_DRY_RUN_ROUTE_PACKET_NEXT_CURSOR
    {
        return Err(
            GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError::PacketInvalid(
                "policy violation",
            ),
        );
    }
    if packet.route_packet_digest != first_runtime_system_g_dry_run_route_packet_digest(packet)? {
        return Err(
            GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError::PacketInvalid(
                "route_packet_digest",
            ),
        );
    }
    Ok(())
}

pub fn first_runtime_system_g_dry_run_route_packet_json_pretty(
    packet: &GemmaFirstRuntimeSystemGDryRunRoutePacket,
) -> Result<Vec<u8>, GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError> {
    validate_first_runtime_system_g_dry_run_route_packet(packet)?;
    let mut bytes = serde_json::to_vec_pretty(packet)?;
    bytes.push(b'\n');
    Ok(bytes)
}

impl GemmaFirstRuntimeSystemGDryRunRoutePacket {
    pub fn system_g_dry_run_route_packet_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_FIRST_RUNTIME_SYSTEM_G_DRY_RUN_ROUTE_PACKET_CURSOR.to_string()),
            self.route_packet_digest.as_bytes(),
            created_at_ms,
        )
    }
}

fn first_runtime_system_g_dry_run_route_packet_digest(
    packet: &GemmaFirstRuntimeSystemGDryRunRoutePacket,
) -> Result<String, GemmaFirstRuntimeSystemGDryRunRoutePacketMaterializerError> {
    let mut clone = packet.clone();
    clone.route_packet_digest.clear();
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
        GemmaFirstRuntimeExecutionObservation, GemmaFirstRuntimeExecutionProbeRequest,
        GemmaFirstRuntimeQualityPacketRequest, GemmaFirstRuntimeQualityReplayRequest,
        GemmaFirstRuntimeQualityTaskObservation,
        GemmaFirstRuntimeRuntimeRouterAdmissionPacketRequest,
        GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest, GemmaQatQualityTaskFamily,
    };

    fn admission_packet() -> GemmaFirstRuntimeRuntimeRouterAdmissionPacket {
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
        materialize_first_runtime_runtime_router_admission_packet(
            &GemmaFirstRuntimeRuntimeRouterAdmissionPacketRequest {
                quality_replay_artifact: replay,
            },
        )
        .expect("admission packet")
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
    fn materializes_zero_action_system_g_dry_run_packet() {
        let packet = materialize_first_runtime_system_g_dry_run_route_packet(
            &GemmaFirstRuntimeSystemGDryRunRoutePacketRequest {
                admission_packet: admission_packet(),
            },
        )
        .expect("system g dry-run packet");

        validate_first_runtime_system_g_dry_run_route_packet(&packet).expect("valid packet");
        assert_eq!(packet.system_g_dry_run_packet_materialized_count, 1);
        assert_eq!(packet.system_g_dry_run_performed_count, 0);
        assert_eq!(packet.runtime_router_mutation_count, 0);
        assert_eq!(packet.system_g_mutation_count, 0);
        assert!(packet.route_answer_packet_visibility_ready);
        assert!(!packet.live_gemma_claim);
        assert_eq!(
            packet.next_cursor,
            GEMMA_FIRST_RUNTIME_SYSTEM_G_DRY_RUN_ROUTE_PACKET_NEXT_CURSOR
        );
    }

    #[test]
    fn blocked_admission_cannot_create_dry_run_packet() {
        let mut admission = admission_packet();
        admission.system_g_dry_run_packet_ready = false;
        admission.runtime_router_admission_packet_ready = false;
        admission.quality_replay_passed = false;
        admission.admission_packet_digest =
            crate::uas::gemma_first_runtime_runtime_router_admission_packet_materializer::first_runtime_runtime_router_admission_packet_json_pretty(&admission)
                .err()
                .map(|_| "sha256:forced-invalid".to_string())
                .unwrap_or_else(|| "sha256:forced-invalid".to_string());
        let result = materialize_first_runtime_system_g_dry_run_route_packet(
            &GemmaFirstRuntimeSystemGDryRunRoutePacketRequest {
                admission_packet: admission,
            },
        );
        assert!(result.is_err());
    }

    #[test]
    fn pretty_json_excludes_raw_path_and_outputs() {
        let packet = materialize_first_runtime_system_g_dry_run_route_packet(
            &GemmaFirstRuntimeSystemGDryRunRoutePacketRequest {
                admission_packet: admission_packet(),
            },
        )
        .expect("system g dry-run packet");
        let json = String::from_utf8(
            first_runtime_system_g_dry_run_route_packet_json_pretty(&packet).unwrap(),
        )
        .expect("utf8");

        assert!(json.contains("route_packet_digest"));
        assert!(json.contains("route_answer_packet_visibility_ready"));
        assert!(!json.contains("/Users/jojo/private"));
        assert!(!json.contains("This note synthesis combines"));
        assert!(!json.contains("Return exactly OK."));
    }
}
