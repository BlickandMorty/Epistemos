//! Gemma first-runtime RuntimeRouter admission packet materializer.
//!
//! This bridge consumes the digest-only same-fixture replay artifact and emits
//! the first concrete RuntimeRouter admission packet artifact. It still does
//! not mutate RuntimeRouter/System G/default state, execute commands, load
//! model bytes, or claim product quality.

use serde::{Deserialize, Serialize};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{
    validate_first_runtime_quality_replay_artifact,
    GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate,
    GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError,
    GemmaFirstRuntimeQualityReplayArtifact, GemmaFirstRuntimeQualityReplayExecutionError,
    UasAddress, UasKind,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_CURSOR,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_ID,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_NEXT_CURSOR,
    GEMMA_FIRST_RUNTIME_QUALITY_REPLAY_EXECUTION_GATE_NEXT_CURSOR,
};

pub const GEMMA_FIRST_RUNTIME_RUNTIME_ROUTER_ADMISSION_PACKET_SCHEMA_VERSION: &str =
    "gemma-first-runtime-runtime-router-admission-packet-v1";
pub const GEMMA_FIRST_RUNTIME_RUNTIME_ROUTER_ADMISSION_PACKET_NEXT_CURSOR: &str =
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_NEXT_CURSOR;

const DIRECT_HARNESS_RUNTIME_LANE: &str = "gemma-direct-harness-llama-cpp-gguf-pro-gated";
const MAX_ADMISSION_METADATA_BYTES: u64 = 320 * 1024;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GemmaFirstRuntimeRuntimeRouterAdmissionPacketRequest {
    pub quality_replay_artifact: GemmaFirstRuntimeQualityReplayArtifact,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaFirstRuntimeRuntimeRouterAdmissionPacket {
    pub schema_version: String,
    pub upstream_quality_replay_artifact_digest: String,
    pub direct_harness_admission_gate_id: String,
    pub selected_model_id: String,
    pub model_identity_digest: String,
    pub llama_cli_identity_digest: String,
    pub runtime_lane: String,
    pub same_fixture_pack_digest: String,
    pub scorer_bundle_digest: String,
    pub quality_summary_digest: String,
    pub failure_taxonomy_digest: String,
    pub budget_vector_digest: String,
    pub memory_headroom_digest: String,
    pub kv_budget_digest: String,
    pub latency_budget_digest: String,
    pub privacy_class_digest: String,
    pub mas_pro_boundary_digest: String,
    pub scope_rex_verdict_digest: String,
    pub sovereign_gate_verdict_digest: String,
    pub route_priority_snapshot_digest: String,
    pub fallback_route_digest: String,
    pub abstention_policy_digest: String,
    pub cancellation_policy_digest: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub visible_caveat_digest: String,
    pub settings_visibility_digest: String,
    pub diagnostic_visibility_digest: String,
    pub no_default_model_mutation_digest: String,
    pub no_hidden_authority_digest: String,
    pub non_promotion_digest: String,
    pub quality_replay_passed: bool,
    pub runtime_router_admission_packet_ready: bool,
    pub system_g_dry_run_packet_ready: bool,
    pub admission_packet_materialized_count: u64,
    pub admission_performed_count: u64,
    pub route_priority_mutation_count: u64,
    pub runtime_router_mutation_count: u64,
    pub system_g_mutation_count: u64,
    pub default_model_mutation_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub process_spawned_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_prompt_bytes_captured: u64,
    pub raw_output_bytes_captured: u64,
    pub answer_packet_suppressed: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub quality_claim: bool,
    pub live_gemma_claim: bool,
    pub l2_l3_t4_claim: bool,
    pub live_dense_70b_claim: bool,
    pub reviewer_visible_summary: String,
    pub metadata_bytes: u64,
    pub next_cursor: String,
    pub admission_packet_digest: String,
}

#[derive(Debug)]
pub enum GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError {
    QualityReplay(GemmaFirstRuntimeQualityReplayExecutionError),
    AdmissionGate(GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError),
    PacketInvalid(&'static str),
    Serialize(serde_json::Error),
}

impl fmt::Display for GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::QualityReplay(error) => write!(f, "quality replay artifact invalid: {error}"),
            Self::AdmissionGate(error) => write!(f, "admission gate invalid: {error}"),
            Self::PacketInvalid(reason) => write!(f, "admission packet invalid: {reason}"),
            Self::Serialize(error) => write!(f, "admission packet serialization error: {error}"),
        }
    }
}

impl std::error::Error for GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError {}

impl From<GemmaFirstRuntimeQualityReplayExecutionError>
    for GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError
{
    fn from(value: GemmaFirstRuntimeQualityReplayExecutionError) -> Self {
        Self::QualityReplay(value)
    }
}

impl From<GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError>
    for GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError
{
    fn from(value: GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError) -> Self {
        Self::AdmissionGate(value)
    }
}

impl From<serde_json::Error> for GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError {
    fn from(value: serde_json::Error) -> Self {
        Self::Serialize(value)
    }
}

pub fn materialize_first_runtime_runtime_router_admission_packet(
    request: &GemmaFirstRuntimeRuntimeRouterAdmissionPacketRequest,
) -> Result<
    GemmaFirstRuntimeRuntimeRouterAdmissionPacket,
    GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError,
> {
    let replay = &request.quality_replay_artifact;
    validate_first_runtime_quality_replay_artifact(replay)?;
    if replay.next_cursor != GEMMA_FIRST_RUNTIME_QUALITY_REPLAY_EXECUTION_GATE_NEXT_CURSOR {
        return Err(
            GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError::PacketInvalid(
                "quality_replay_artifact.next_cursor",
            ),
        );
    }

    let gate = GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate::canonical();
    gate.validate()?;

    let quality_replay_passed =
        replay.route_admission_packet_ready && replay.failed_task_count == 0;
    let mut packet = GemmaFirstRuntimeRuntimeRouterAdmissionPacket {
        schema_version: GEMMA_FIRST_RUNTIME_RUNTIME_ROUTER_ADMISSION_PACKET_SCHEMA_VERSION
            .to_string(),
        upstream_quality_replay_artifact_digest: replay.artifact_digest.clone(),
        direct_harness_admission_gate_id:
            GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_ID
                .to_string(),
        selected_model_id: replay.selected_model_id.clone(),
        model_identity_digest: replay.model_identity_digest.clone(),
        llama_cli_identity_digest: replay.llama_cli_identity_digest.clone(),
        runtime_lane: DIRECT_HARNESS_RUNTIME_LANE.to_string(),
        same_fixture_pack_digest: replay.same_fixture_pack_digest.clone(),
        scorer_bundle_digest: replay.scorer_bundle_digest.clone(),
        quality_summary_digest: replay.quality_summary_digest.clone(),
        failure_taxonomy_digest: replay.failure_taxonomy_digest.clone(),
        budget_vector_digest: policy_digest(
            "budget-vector",
            &[&replay.selected_model_id, &replay.same_fixture_pack_digest],
        ),
        memory_headroom_digest: policy_digest(
            "memory-headroom",
            &[&replay.model_identity_digest, &replay.quality_summary_digest],
        ),
        kv_budget_digest: policy_digest(
            "kv-budget",
            &[&replay.model_identity_digest, &replay.failure_taxonomy_digest],
        ),
        latency_budget_digest: policy_digest(
            "latency-budget",
            &[&replay.quality_summary_digest, &replay.failure_taxonomy_digest],
        ),
        privacy_class_digest: policy_digest(
            "privacy-class",
            &[&replay.upstream_quality_packet_digest, "digest-only"],
        ),
        mas_pro_boundary_digest: policy_digest(
            "mas-pro-boundary",
            &[&gate.runtime_lane, "pro-gated-non-default"],
        ),
        scope_rex_verdict_digest: policy_digest(
            "scope-rex-verdict",
            &[&gate.scope_rex_verdict_ref, "packet-only"],
        ),
        sovereign_gate_verdict_digest: policy_digest(
            "sovereign-gate-verdict",
            &[&gate.sovereign_gate_verdict_ref, "packet-only"],
        ),
        route_priority_snapshot_digest: policy_digest(
            "route-priority-snapshot",
            &[&gate.runtime_lane, "no-priority-mutation"],
        ),
        fallback_route_digest: policy_digest("fallback-route", &[&gate.fallback_route_ref]),
        abstention_policy_digest: policy_digest(
            "abstention-policy",
            &[&gate.abstention_policy_ref],
        ),
        cancellation_policy_digest: policy_digest(
            "cancellation-policy",
            &[&gate.cancellation_policy_ref],
        ),
        rollback_ref: "rollback:gemma-first-runtime-runtime-router-admission-packet-v1"
            .to_string(),
        run_event_log_ref:
            "run_event_log:gemma-first-runtime-runtime-router-admission-packet-v1"
                .to_string(),
        answer_packet_ref:
            "answer_packet:gemma-first-runtime-runtime-router-admission-packet-v1"
                .to_string(),
        visible_caveat_digest: policy_digest(
            "visible-caveat",
            &[if quality_replay_passed {
                "ready-for-system-g-dry-run-not-user-facing"
            } else {
                "quality-replay-failed-route-blocked"
            }],
        ),
        settings_visibility_digest: policy_digest(
            "settings-visibility",
            &["gemma-proof-lane-admission-packet-visible"],
        ),
        diagnostic_visibility_digest: policy_digest(
            "diagnostic-visibility",
            &["gemma-proof-lane-admission-packet-digest-only"],
        ),
        no_default_model_mutation_digest: policy_digest(
            "no-default-model-mutation",
            &["default-model-unchanged"],
        ),
        no_hidden_authority_digest: policy_digest(
            "no-hidden-authority",
            &["runtime-router-system-g-patternboost-lattice-no-hidden-authority"],
        ),
        non_promotion_digest: policy_digest(
            "non-promotion",
            &["no-mas-l2-l3-t4-live-default-quality-claim"],
        ),
        quality_replay_passed,
        runtime_router_admission_packet_ready: quality_replay_passed,
        system_g_dry_run_packet_ready: quality_replay_passed,
        admission_packet_materialized_count: 1,
        admission_performed_count: 0,
        route_priority_mutation_count: 0,
        runtime_router_mutation_count: 0,
        system_g_mutation_count: 0,
        default_model_mutation_count: 0,
        command_armed_count: 0,
        command_executed_count: 0,
        process_spawned_count: 0,
        model_bytes_loaded: 0,
        runtime_bytes_loaded: 0,
        provider_calls_made: 0,
        raw_prompt_bytes_captured: 0,
        raw_output_bytes_captured: 0,
        answer_packet_suppressed: false,
        hidden_route_authority: false,
        hidden_cloud_fallback: false,
        quality_claim: false,
        live_gemma_claim: false,
        l2_l3_t4_claim: false,
        live_dense_70b_claim: false,
        reviewer_visible_summary: if quality_replay_passed {
            "Gemma first-runtime replay produced a digest-only RuntimeRouter admission packet; this is ready only for a separate System G dry-run packet and is not user-facing."
        } else {
            "Gemma first-runtime replay failed at least one deterministic task; RuntimeRouter admission remains blocked and no System G dry-run packet is ready."
        }
        .to_string(),
        metadata_bytes: 128 * 1024,
        next_cursor: GEMMA_FIRST_RUNTIME_RUNTIME_ROUTER_ADMISSION_PACKET_NEXT_CURSOR
            .to_string(),
        admission_packet_digest: String::new(),
    };
    packet.admission_packet_digest = first_runtime_runtime_router_admission_packet_digest(&packet)?;
    validate_first_runtime_runtime_router_admission_packet(&packet)?;
    Ok(packet)
}

pub fn validate_first_runtime_runtime_router_admission_packet(
    packet: &GemmaFirstRuntimeRuntimeRouterAdmissionPacket,
) -> Result<(), GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError> {
    if packet.schema_version != GEMMA_FIRST_RUNTIME_RUNTIME_ROUTER_ADMISSION_PACKET_SCHEMA_VERSION {
        return Err(
            GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError::PacketInvalid(
                "schema_version",
            ),
        );
    }
    if packet.direct_harness_admission_gate_id
        != GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_ID
        || packet.runtime_lane != DIRECT_HARNESS_RUNTIME_LANE
    {
        return Err(
            GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError::PacketInvalid(
                "runtime_lane",
            ),
        );
    }
    for (field, value) in [
        (
            "upstream_quality_replay_artifact_digest",
            &packet.upstream_quality_replay_artifact_digest,
        ),
        ("model_identity_digest", &packet.model_identity_digest),
        (
            "llama_cli_identity_digest",
            &packet.llama_cli_identity_digest,
        ),
        ("quality_summary_digest", &packet.quality_summary_digest),
        ("failure_taxonomy_digest", &packet.failure_taxonomy_digest),
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
        (
            "route_priority_snapshot_digest",
            &packet.route_priority_snapshot_digest,
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
        (
            "no_default_model_mutation_digest",
            &packet.no_default_model_mutation_digest,
        ),
        (
            "no_hidden_authority_digest",
            &packet.no_hidden_authority_digest,
        ),
        ("non_promotion_digest", &packet.non_promotion_digest),
        ("admission_packet_digest", &packet.admission_packet_digest),
    ] {
        if !value.starts_with("sha256:") {
            return Err(
                GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError::PacketInvalid(
                    field,
                ),
            );
        }
    }
    if !packet
        .same_fixture_pack_digest
        .starts_with("fixture_pack:sha256:")
        || !packet
            .scorer_bundle_digest
            .starts_with("scorer_bundle:sha256:")
    {
        return Err(
            GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError::PacketInvalid(
                "fixture_or_scorer_digest",
            ),
        );
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
                GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError::PacketInvalid(
                    field,
                ),
            );
        }
    }
    if packet.runtime_router_admission_packet_ready != packet.quality_replay_passed
        || packet.system_g_dry_run_packet_ready != packet.quality_replay_passed
        || packet.admission_packet_materialized_count != 1
        || packet.admission_performed_count != 0
        || packet.route_priority_mutation_count != 0
        || packet.runtime_router_mutation_count != 0
        || packet.system_g_mutation_count != 0
        || packet.default_model_mutation_count != 0
        || packet.command_armed_count != 0
        || packet.command_executed_count != 0
        || packet.process_spawned_count != 0
        || packet.model_bytes_loaded != 0
        || packet.runtime_bytes_loaded != 0
        || packet.provider_calls_made != 0
        || packet.raw_prompt_bytes_captured != 0
        || packet.raw_output_bytes_captured != 0
        || packet.answer_packet_suppressed
        || packet.hidden_route_authority
        || packet.hidden_cloud_fallback
        || packet.quality_claim
        || packet.live_gemma_claim
        || packet.l2_l3_t4_claim
        || packet.live_dense_70b_claim
        || packet.metadata_bytes > MAX_ADMISSION_METADATA_BYTES
        || packet.next_cursor != GEMMA_FIRST_RUNTIME_RUNTIME_ROUTER_ADMISSION_PACKET_NEXT_CURSOR
    {
        return Err(
            GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError::PacketInvalid(
                "policy violation",
            ),
        );
    }
    if packet.admission_packet_digest
        != first_runtime_runtime_router_admission_packet_digest(packet)?
    {
        return Err(
            GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError::PacketInvalid(
                "admission_packet_digest",
            ),
        );
    }
    Ok(())
}

pub fn first_runtime_runtime_router_admission_packet_json_pretty(
    packet: &GemmaFirstRuntimeRuntimeRouterAdmissionPacket,
) -> Result<Vec<u8>, GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError> {
    validate_first_runtime_runtime_router_admission_packet(packet)?;
    let mut bytes = serde_json::to_vec_pretty(packet)?;
    bytes.push(b'\n');
    Ok(bytes)
}

impl GemmaFirstRuntimeRuntimeRouterAdmissionPacket {
    pub fn runtime_router_admission_packet_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_CURSOR
                    .to_string(),
            ),
            self.admission_packet_digest.as_bytes(),
            created_at_ms,
        )
    }
}

fn first_runtime_runtime_router_admission_packet_digest(
    packet: &GemmaFirstRuntimeRuntimeRouterAdmissionPacket,
) -> Result<String, GemmaFirstRuntimeRuntimeRouterAdmissionPacketMaterializerError> {
    let mut clone = packet.clone();
    clone.admission_packet_digest.clear();
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
        GemmaFirstRuntimeExecutionObservation, GemmaFirstRuntimeExecutionProbeRequest,
        GemmaFirstRuntimeQualityPacket, GemmaFirstRuntimeQualityPacketRequest,
        GemmaFirstRuntimeQualityReplayRequest, GemmaFirstRuntimeQualityTaskObservation,
        GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest, GemmaQatQualityTaskFamily,
    };

    fn quality_packet() -> GemmaFirstRuntimeQualityPacket {
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

        materialize_first_runtime_quality_packet(&GemmaFirstRuntimeQualityPacketRequest {
            runtime_receipt,
        })
        .expect("quality packet")
    }

    fn observations(
        packet: &GemmaFirstRuntimeQualityPacket,
    ) -> Vec<GemmaFirstRuntimeQualityTaskObservation> {
        packet
            .task_packets
            .iter()
            .map(|task| {
                let candidate_output = match task.task_family {
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
                };
                GemmaFirstRuntimeQualityTaskObservation {
                    task_family: task.task_family,
                    task_descriptor_digest: task.task_descriptor_digest.clone(),
                    expected_output_shape_digest: task.expected_output_shape_digest.clone(),
                    fixture_prompt_digest: sha256_hex(
                        format!("{:?}:prompt", task.task_family).as_bytes(),
                    ),
                    candidate_output: candidate_output.to_string(),
                    duration_ms: 25,
                    exit_code: 0,
                    timed_out: false,
                    cache_deleted_before_replay: true,
                    contamination_check_passed: true,
                }
            })
            .collect()
    }

    fn replay_artifact() -> GemmaFirstRuntimeQualityReplayArtifact {
        let packet = quality_packet();
        execute_first_runtime_quality_replay(&GemmaFirstRuntimeQualityReplayRequest {
            observations: observations(&packet),
            quality_packet: packet,
        })
        .expect("quality replay")
    }

    #[test]
    fn materializes_digest_only_admission_packet_from_passing_replay() {
        let replay = replay_artifact();
        let packet = materialize_first_runtime_runtime_router_admission_packet(
            &GemmaFirstRuntimeRuntimeRouterAdmissionPacketRequest {
                quality_replay_artifact: replay,
            },
        )
        .expect("admission packet");

        validate_first_runtime_runtime_router_admission_packet(&packet).expect("valid packet");
        assert!(packet.quality_replay_passed);
        assert!(packet.runtime_router_admission_packet_ready);
        assert!(packet.system_g_dry_run_packet_ready);
        assert_eq!(packet.admission_performed_count, 0);
        assert_eq!(packet.runtime_router_mutation_count, 0);
        assert_eq!(packet.system_g_mutation_count, 0);
        assert!(!packet.quality_claim);
        assert_eq!(
            packet.next_cursor,
            GEMMA_FIRST_RUNTIME_RUNTIME_ROUTER_ADMISSION_PACKET_NEXT_CURSOR
        );
    }

    #[test]
    fn failed_replay_materializes_blocked_packet_without_route_authority() {
        let packet = quality_packet();
        let mut observations = observations(&packet);
        observations
            .iter_mut()
            .find(|observation| {
                observation.task_family == GemmaQatQualityTaskFamily::StructuredToolJson
            })
            .expect("json task")
            .candidate_output = "not json".to_string();
        let replay = execute_first_runtime_quality_replay(&GemmaFirstRuntimeQualityReplayRequest {
            observations,
            quality_packet: packet,
        })
        .expect("failed replay artifact");

        let packet = materialize_first_runtime_runtime_router_admission_packet(
            &GemmaFirstRuntimeRuntimeRouterAdmissionPacketRequest {
                quality_replay_artifact: replay,
            },
        )
        .expect("blocked packet");
        assert!(!packet.quality_replay_passed);
        assert!(!packet.runtime_router_admission_packet_ready);
        assert!(!packet.system_g_dry_run_packet_ready);
        assert_eq!(packet.admission_performed_count, 0);
    }

    #[test]
    fn pretty_json_excludes_raw_model_path_and_outputs() {
        let replay = replay_artifact();
        let packet = materialize_first_runtime_runtime_router_admission_packet(
            &GemmaFirstRuntimeRuntimeRouterAdmissionPacketRequest {
                quality_replay_artifact: replay,
            },
        )
        .expect("admission packet");
        let json = String::from_utf8(
            first_runtime_runtime_router_admission_packet_json_pretty(&packet).unwrap(),
        )
        .expect("utf8");

        assert!(json.contains("admission_packet_digest"));
        assert!(json.contains("runtime_router_admission_packet_ready"));
        assert!(!json.contains("/Users/jojo/private"));
        assert!(!json.contains("This note synthesis combines"));
        assert!(!json.contains("Return exactly OK."));
    }
}
