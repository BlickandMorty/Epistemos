//! Gemma first-runtime same-fixture quality packet materializer.
//!
//! This bridge consumes the owner-approved first-runtime execution receipt and
//! emits a digest-only quality replay packet. It prepares the same-fixture
//! replay surface without opening fixture payloads, running scorers, judging
//! output, admitting RuntimeRouter routes, mutating System G, or making a
//! quality/product claim.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{
    validate_first_runtime_execution_receipt,
    GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate,
    GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError,
    GemmaFirstRuntimeExecutionProbeError, GemmaFirstRuntimeExecutionProbeReceipt,
    GemmaQatQualityTaskFamily, UasAddress, UasKind,
    GEMMA_FIRST_RUNTIME_EXECUTION_PROBE_NEXT_CURSOR,
};

pub const GEMMA_FIRST_RUNTIME_QUALITY_PACKET_MATERIALIZER_CURSOR: &str =
    "gemma_direct_harness_owner_approved_first_runtime_quality_packet_materializer";
pub const GEMMA_FIRST_RUNTIME_QUALITY_PACKET_MATERIALIZER_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_same_fixture_quality_replay_execution_gate";
pub const GEMMA_FIRST_RUNTIME_QUALITY_PACKET_MATERIALIZER_SCHEMA_VERSION: &str =
    "gemma-first-runtime-same-fixture-quality-packet-v1";

const SCORING_STATUS_NOT_RUN: &str = "not_scored_replay_pending";
const MAX_METADATA_BYTES: u64 = 192 * 1024;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GemmaFirstRuntimeQualityPacketRequest {
    pub runtime_receipt: GemmaFirstRuntimeExecutionProbeReceipt,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaFirstRuntimeQualityTaskPacket {
    pub task_family: GemmaQatQualityTaskFamily,
    pub task_descriptor_digest: String,
    pub expected_output_shape_digest: String,
    pub scoring_status: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaFirstRuntimeQualityPacket {
    pub schema_version: String,
    pub upstream_runtime_receipt_digest: String,
    pub selected_model_id: String,
    pub owner_approval_phrase_digest: String,
    pub model_identity_digest: String,
    pub llama_cli_identity_digest: String,
    pub prompt_digest: String,
    pub command_argv_digest: String,
    pub stdout_digest: String,
    pub stderr_digest: String,
    pub first_token_digest: String,
    pub same_fixture_pack_digest: String,
    pub scorer_bundle_digest: String,
    pub task_family_digest: String,
    pub task_packets: Vec<GemmaFirstRuntimeQualityTaskPacket>,
    pub runtime_receipt_present_count: u64,
    pub quality_replay_performed_count: u64,
    pub scorer_executions: u64,
    pub fixture_payload_bytes_opened: u64,
    pub raw_prompt_bytes_captured: u64,
    pub raw_context_bytes_captured: u64,
    pub raw_output_bytes_captured: u64,
    pub raw_judge_bytes_captured: u64,
    pub runtime_router_mutation_count: u64,
    pub system_g_mutation_count: u64,
    pub settings_default_mutation_count: u64,
    pub quality_claim: bool,
    pub live_gemma_claim: bool,
    pub l2_l3_t4_claim: bool,
    pub live_dense_70b_claim: bool,
    pub reviewer_visible_summary: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub non_promotion_ref: String,
    pub metadata_bytes: u64,
    pub next_cursor: String,
    pub packet_digest: String,
}

#[derive(Debug)]
pub enum GemmaFirstRuntimeQualityPacketMaterializerError {
    RuntimeReceipt(GemmaFirstRuntimeExecutionProbeError),
    QualityGate(GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError),
    BadTaskFamilyCoverage,
    PacketInvalid(&'static str),
    Serialize(serde_json::Error),
}

impl fmt::Display for GemmaFirstRuntimeQualityPacketMaterializerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::RuntimeReceipt(error) => write!(f, "runtime receipt invalid: {error}"),
            Self::QualityGate(error) => write!(f, "quality gate invalid: {error}"),
            Self::BadTaskFamilyCoverage => write!(f, "task family coverage is incomplete"),
            Self::PacketInvalid(reason) => write!(f, "quality packet invalid: {reason}"),
            Self::Serialize(error) => write!(f, "quality packet serialization error: {error}"),
        }
    }
}

impl std::error::Error for GemmaFirstRuntimeQualityPacketMaterializerError {}

impl From<GemmaFirstRuntimeExecutionProbeError>
    for GemmaFirstRuntimeQualityPacketMaterializerError
{
    fn from(value: GemmaFirstRuntimeExecutionProbeError) -> Self {
        Self::RuntimeReceipt(value)
    }
}

impl From<GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError>
    for GemmaFirstRuntimeQualityPacketMaterializerError
{
    fn from(value: GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError) -> Self {
        Self::QualityGate(value)
    }
}

impl From<serde_json::Error> for GemmaFirstRuntimeQualityPacketMaterializerError {
    fn from(value: serde_json::Error) -> Self {
        Self::Serialize(value)
    }
}

pub fn materialize_first_runtime_quality_packet(
    request: &GemmaFirstRuntimeQualityPacketRequest,
) -> Result<GemmaFirstRuntimeQualityPacket, GemmaFirstRuntimeQualityPacketMaterializerError> {
    validate_first_runtime_execution_receipt(&request.runtime_receipt)?;
    if request.runtime_receipt.next_cursor != GEMMA_FIRST_RUNTIME_EXECUTION_PROBE_NEXT_CURSOR {
        return Err(
            GemmaFirstRuntimeQualityPacketMaterializerError::PacketInvalid(
                "runtime receipt next_cursor",
            ),
        );
    }

    let gate = GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate::canonical();
    gate.validate()?;
    let task_packets = task_packets(&gate.task_families);
    validate_task_family_coverage(&task_packets, &gate.task_families)?;

    let mut packet = GemmaFirstRuntimeQualityPacket {
        schema_version: GEMMA_FIRST_RUNTIME_QUALITY_PACKET_MATERIALIZER_SCHEMA_VERSION.to_string(),
        upstream_runtime_receipt_digest: request.runtime_receipt.receipt_digest.clone(),
        selected_model_id: request.runtime_receipt.selected_model_id.clone(),
        owner_approval_phrase_digest: request
            .runtime_receipt
            .owner_approval_phrase_digest
            .clone(),
        model_identity_digest: model_identity_digest(&request.runtime_receipt),
        llama_cli_identity_digest: llama_cli_identity_digest(&request.runtime_receipt),
        prompt_digest: request.runtime_receipt.prompt_digest.clone(),
        command_argv_digest: request.runtime_receipt.command_argv_digest.clone(),
        stdout_digest: request.runtime_receipt.stdout_digest.clone(),
        stderr_digest: request.runtime_receipt.stderr_digest.clone(),
        first_token_digest: request.runtime_receipt.first_token_digest.clone(),
        same_fixture_pack_digest: gate.fixture_pack_digest,
        scorer_bundle_digest: gate.scorer_bundle_digest,
        task_family_digest: task_family_digest(&task_packets)?,
        task_packets,
        runtime_receipt_present_count: 1,
        quality_replay_performed_count: 0,
        scorer_executions: 0,
        fixture_payload_bytes_opened: 0,
        raw_prompt_bytes_captured: 0,
        raw_context_bytes_captured: 0,
        raw_output_bytes_captured: 0,
        raw_judge_bytes_captured: 0,
        runtime_router_mutation_count: 0,
        system_g_mutation_count: 0,
        settings_default_mutation_count: 0,
        quality_claim: false,
        live_gemma_claim: false,
        l2_l3_t4_claim: false,
        live_dense_70b_claim: false,
        reviewer_visible_summary:
            "Gemma first-runtime receipt is packaged for same-fixture quality replay; no fixture payload, scorer, judge, route admission, System G mutation, or quality claim has run."
                .to_string(),
        rollback_ref: "rollback:gemma-first-runtime-quality-packet-materializer-v1".to_string(),
        run_event_log_ref: "run_event_log:gemma-first-runtime-quality-packet-materializer-v1"
            .to_string(),
        answer_packet_ref: "answer_packet:gemma-first-runtime-quality-packet-materializer-v1"
            .to_string(),
        abstention_ref: "abstention:gemma-first-runtime-quality-packet-materializer-v1"
            .to_string(),
        non_promotion_ref: "non_promotion:gemma-first-runtime-quality-packet-materializer-v1"
            .to_string(),
        metadata_bytes: 64 * 1024,
        next_cursor: GEMMA_FIRST_RUNTIME_QUALITY_PACKET_MATERIALIZER_NEXT_CURSOR.to_string(),
        packet_digest: String::new(),
    };
    packet.packet_digest = first_runtime_quality_packet_digest(&packet)?;
    validate_first_runtime_quality_packet(&packet)?;
    Ok(packet)
}

pub fn validate_first_runtime_quality_packet(
    packet: &GemmaFirstRuntimeQualityPacket,
) -> Result<(), GemmaFirstRuntimeQualityPacketMaterializerError> {
    if packet.schema_version != GEMMA_FIRST_RUNTIME_QUALITY_PACKET_MATERIALIZER_SCHEMA_VERSION {
        return Err(
            GemmaFirstRuntimeQualityPacketMaterializerError::PacketInvalid("schema_version"),
        );
    }
    for (field, value) in [
        (
            "upstream_runtime_receipt_digest",
            &packet.upstream_runtime_receipt_digest,
        ),
        (
            "owner_approval_phrase_digest",
            &packet.owner_approval_phrase_digest,
        ),
        ("model_identity_digest", &packet.model_identity_digest),
        (
            "llama_cli_identity_digest",
            &packet.llama_cli_identity_digest,
        ),
        ("prompt_digest", &packet.prompt_digest),
        ("command_argv_digest", &packet.command_argv_digest),
        ("stdout_digest", &packet.stdout_digest),
        ("stderr_digest", &packet.stderr_digest),
        ("first_token_digest", &packet.first_token_digest),
        ("task_family_digest", &packet.task_family_digest),
        ("packet_digest", &packet.packet_digest),
    ] {
        if !value.starts_with("sha256:") {
            return Err(GemmaFirstRuntimeQualityPacketMaterializerError::PacketInvalid(field));
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
            GemmaFirstRuntimeQualityPacketMaterializerError::PacketInvalid(
                "fixture_or_scorer_digest",
            ),
        );
    }
    if packet.runtime_receipt_present_count != 1
        || packet.quality_replay_performed_count != 0
        || packet.scorer_executions != 0
        || packet.fixture_payload_bytes_opened != 0
        || packet.raw_prompt_bytes_captured != 0
        || packet.raw_context_bytes_captured != 0
        || packet.raw_output_bytes_captured != 0
        || packet.raw_judge_bytes_captured != 0
        || packet.runtime_router_mutation_count != 0
        || packet.system_g_mutation_count != 0
        || packet.settings_default_mutation_count != 0
        || packet.quality_claim
        || packet.live_gemma_claim
        || packet.l2_l3_t4_claim
        || packet.live_dense_70b_claim
        || packet.metadata_bytes > MAX_METADATA_BYTES
        || packet.next_cursor != GEMMA_FIRST_RUNTIME_QUALITY_PACKET_MATERIALIZER_NEXT_CURSOR
    {
        return Err(
            GemmaFirstRuntimeQualityPacketMaterializerError::PacketInvalid("policy violation"),
        );
    }
    validate_task_family_coverage(&packet.task_packets, &families_from_task_packets(packet))?;
    if packet.task_family_digest != task_family_digest(&packet.task_packets)? {
        return Err(
            GemmaFirstRuntimeQualityPacketMaterializerError::PacketInvalid("task_family_digest"),
        );
    }
    if packet.packet_digest != first_runtime_quality_packet_digest(packet)? {
        return Err(
            GemmaFirstRuntimeQualityPacketMaterializerError::PacketInvalid("packet_digest"),
        );
    }
    Ok(())
}

pub fn first_runtime_quality_packet_json_pretty(
    packet: &GemmaFirstRuntimeQualityPacket,
) -> Result<Vec<u8>, GemmaFirstRuntimeQualityPacketMaterializerError> {
    validate_first_runtime_quality_packet(packet)?;
    let mut bytes = serde_json::to_vec_pretty(packet)?;
    bytes.push(b'\n');
    Ok(bytes)
}

impl GemmaFirstRuntimeQualityPacket {
    pub fn quality_packet_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_FIRST_RUNTIME_QUALITY_PACKET_MATERIALIZER_CURSOR.to_string()),
            self.packet_digest.as_bytes(),
            created_at_ms,
        )
    }
}

fn task_packets(families: &[GemmaQatQualityTaskFamily]) -> Vec<GemmaFirstRuntimeQualityTaskPacket> {
    families
        .iter()
        .copied()
        .map(|family| {
            let family_tag = format!("{family:?}").to_ascii_lowercase();
            GemmaFirstRuntimeQualityTaskPacket {
                task_family: family,
                task_descriptor_digest: sha256_hex(
                    format!("gemma-first-runtime-quality-task:{family_tag}:descriptor-v1")
                        .as_bytes(),
                ),
                expected_output_shape_digest: sha256_hex(
                    format!("gemma-first-runtime-quality-task:{family_tag}:expected-output-v1")
                        .as_bytes(),
                ),
                scoring_status: SCORING_STATUS_NOT_RUN.to_string(),
            }
        })
        .collect()
}

fn validate_task_family_coverage(
    packets: &[GemmaFirstRuntimeQualityTaskPacket],
    expected: &[GemmaQatQualityTaskFamily],
) -> Result<(), GemmaFirstRuntimeQualityPacketMaterializerError> {
    let actual_set: BTreeSet<GemmaQatQualityTaskFamily> =
        packets.iter().map(|packet| packet.task_family).collect();
    let expected_set: BTreeSet<GemmaQatQualityTaskFamily> = expected.iter().copied().collect();
    if packets.len() != expected.len()
        || actual_set.len() != packets.len()
        || actual_set != expected_set
    {
        return Err(GemmaFirstRuntimeQualityPacketMaterializerError::BadTaskFamilyCoverage);
    }
    for packet in packets {
        if !packet.task_descriptor_digest.starts_with("sha256:")
            || !packet.expected_output_shape_digest.starts_with("sha256:")
            || packet.scoring_status != SCORING_STATUS_NOT_RUN
        {
            return Err(
                GemmaFirstRuntimeQualityPacketMaterializerError::PacketInvalid("task_packet"),
            );
        }
    }
    Ok(())
}

fn families_from_task_packets(
    packet: &GemmaFirstRuntimeQualityPacket,
) -> Vec<GemmaQatQualityTaskFamily> {
    packet
        .task_packets
        .iter()
        .map(|task| task.task_family)
        .collect()
}

fn task_family_digest(
    packets: &[GemmaFirstRuntimeQualityTaskPacket],
) -> Result<String, GemmaFirstRuntimeQualityPacketMaterializerError> {
    let mut clone = packets.to_vec();
    clone.sort_by_key(|packet| packet.task_family);
    Ok(sha256_hex(&serde_json::to_vec(&clone)?))
}

fn model_identity_digest(receipt: &GemmaFirstRuntimeExecutionProbeReceipt) -> String {
    sha256_hex(
        format!(
            "{}|{}|{}|{}",
            receipt.selected_model_id,
            receipt.expected_byte_count,
            receipt.observed_byte_count,
            receipt.local_file_sha256
        )
        .as_bytes(),
    )
}

fn llama_cli_identity_digest(receipt: &GemmaFirstRuntimeExecutionProbeReceipt) -> String {
    sha256_hex(
        format!(
            "{}|{}",
            receipt.llama_cli_version_digest, receipt.llama_cli_help_digest
        )
        .as_bytes(),
    )
}

fn first_runtime_quality_packet_digest(
    packet: &GemmaFirstRuntimeQualityPacket,
) -> Result<String, GemmaFirstRuntimeQualityPacketMaterializerError> {
    let mut clone = packet.clone();
    clone.packet_digest.clear();
    Ok(sha256_hex(&serde_json::to_vec(&clone)?))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{
        build_first_runtime_execution_receipt, build_receipt_from_observed_material,
        GemmaFirstRuntimeExecutionObservation, GemmaFirstRuntimeExecutionProbeRequest,
        GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest,
    };

    fn runtime_receipt() -> GemmaFirstRuntimeExecutionProbeReceipt {
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

        build_first_runtime_execution_receipt(
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
        .expect("runtime receipt")
    }

    #[test]
    fn materializes_replay_ready_quality_packet_without_quality_claim() {
        let receipt = runtime_receipt();
        let packet =
            materialize_first_runtime_quality_packet(&GemmaFirstRuntimeQualityPacketRequest {
                runtime_receipt: receipt,
            })
            .expect("quality packet");

        validate_first_runtime_quality_packet(&packet).expect("valid packet");
        assert_eq!(packet.runtime_receipt_present_count, 1);
        assert_eq!(packet.task_packets.len(), 7);
        assert_eq!(packet.quality_replay_performed_count, 0);
        assert_eq!(packet.scorer_executions, 0);
        assert_eq!(packet.fixture_payload_bytes_opened, 0);
        assert_eq!(packet.runtime_router_mutation_count, 0);
        assert_eq!(packet.system_g_mutation_count, 0);
        assert!(!packet.quality_claim);
        assert_eq!(
            packet.next_cursor,
            GEMMA_FIRST_RUNTIME_QUALITY_PACKET_MATERIALIZER_NEXT_CURSOR
        );
    }

    #[test]
    fn pretty_json_keeps_raw_runtime_material_out() {
        let packet =
            materialize_first_runtime_quality_packet(&GemmaFirstRuntimeQualityPacketRequest {
                runtime_receipt: runtime_receipt(),
            })
            .expect("quality packet");
        let json = String::from_utf8(first_runtime_quality_packet_json_pretty(&packet).unwrap())
            .expect("utf8");

        assert!(json.contains("upstream_runtime_receipt_digest"));
        assert!(json.contains("not_scored_replay_pending"));
        assert!(!json.contains("/Users/jojo/private"));
        assert!(!json.contains("Return exactly OK."));
        assert!(!json.contains("timings"));
    }

    #[test]
    fn rejects_runtime_receipt_mutation_or_quality_promotion() {
        let mut receipt = runtime_receipt();
        receipt.runtime_router_mutation_count = 1;
        assert!(matches!(
            materialize_first_runtime_quality_packet(&GemmaFirstRuntimeQualityPacketRequest {
                runtime_receipt: receipt,
            }),
            Err(GemmaFirstRuntimeQualityPacketMaterializerError::RuntimeReceipt(_))
        ));

        let mut packet =
            materialize_first_runtime_quality_packet(&GemmaFirstRuntimeQualityPacketRequest {
                runtime_receipt: runtime_receipt(),
            })
            .expect("quality packet");
        packet.quality_claim = true;
        packet.packet_digest = first_runtime_quality_packet_digest(&packet).unwrap();
        assert!(matches!(
            validate_first_runtime_quality_packet(&packet),
            Err(GemmaFirstRuntimeQualityPacketMaterializerError::PacketInvalid("policy violation"))
        ));
    }

    #[test]
    fn address_is_stable_for_same_packet_digest() {
        let packet =
            materialize_first_runtime_quality_packet(&GemmaFirstRuntimeQualityPacketRequest {
                runtime_receipt: runtime_receipt(),
            })
            .expect("quality packet");

        assert_eq!(
            packet.quality_packet_address(1_780_000_000_000),
            packet.quality_packet_address(1_780_000_000_000)
        );
    }
}
