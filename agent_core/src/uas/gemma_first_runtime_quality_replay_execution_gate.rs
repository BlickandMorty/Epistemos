//! Gemma first-runtime same-fixture quality replay execution gate.
//!
//! This is the first concrete replay/scorer bridge after the digest-only
//! quality packet. It scores task observations in memory, emits only digests and
//! verifier verdicts, and still refuses RuntimeRouter/System G/default
//! mutation or a user-facing quality claim.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{
    validate_first_runtime_quality_packet, GemmaFirstRuntimeQualityPacket,
    GemmaFirstRuntimeQualityPacketMaterializerError, GemmaQatQualityTaskFamily, UasAddress,
    UasKind, GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_CURSOR,
    GEMMA_FIRST_RUNTIME_QUALITY_PACKET_MATERIALIZER_NEXT_CURSOR,
};

pub const GEMMA_FIRST_RUNTIME_QUALITY_REPLAY_EXECUTION_GATE_CURSOR: &str =
    "gemma_direct_harness_owner_approved_same_fixture_quality_replay_execution_gate";
pub const GEMMA_FIRST_RUNTIME_QUALITY_REPLAY_EXECUTION_GATE_NEXT_CURSOR: &str =
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_CURSOR;
pub const GEMMA_FIRST_RUNTIME_QUALITY_REPLAY_EXECUTION_GATE_SCHEMA_VERSION: &str =
    "gemma-first-runtime-same-fixture-quality-replay-execution-v1";

const MAX_TASK_OUTPUT_BYTES: usize = 8 * 1024;
const MAX_REPLAY_METADATA_BYTES: u64 = 256 * 1024;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GemmaFirstRuntimeQualityReplayRequest {
    pub quality_packet: GemmaFirstRuntimeQualityPacket,
    pub observations: Vec<GemmaFirstRuntimeQualityTaskObservation>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaFirstRuntimeQualityTaskObservation {
    pub task_family: GemmaQatQualityTaskFamily,
    pub task_descriptor_digest: String,
    pub expected_output_shape_digest: String,
    pub fixture_prompt_digest: String,
    pub candidate_output: String,
    pub duration_ms: u64,
    pub exit_code: i32,
    pub timed_out: bool,
    pub cache_deleted_before_replay: bool,
    pub contamination_check_passed: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaFirstRuntimeQualityReplayObservationEnvelope {
    pub observations: Vec<GemmaFirstRuntimeQualityTaskObservation>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaFirstRuntimeQualityTaskReplayResult {
    pub task_family: GemmaQatQualityTaskFamily,
    pub task_descriptor_digest: String,
    pub expected_output_shape_digest: String,
    pub fixture_prompt_digest: String,
    pub candidate_output_digest: String,
    pub redacted_output_shape_digest: String,
    pub deterministic_scorer_digest: String,
    pub score: u8,
    pub passed: bool,
    pub failure_codes: Vec<String>,
    pub duration_ms: u64,
    pub exit_status_digest: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaFirstRuntimeQualityReplayArtifact {
    pub schema_version: String,
    pub upstream_quality_packet_digest: String,
    pub selected_model_id: String,
    pub model_identity_digest: String,
    pub llama_cli_identity_digest: String,
    pub same_fixture_pack_digest: String,
    pub scorer_bundle_digest: String,
    pub task_family_digest: String,
    pub task_results: Vec<GemmaFirstRuntimeQualityTaskReplayResult>,
    pub quality_replay_performed_count: u64,
    pub scorer_executions: u64,
    pub passed_task_count: u64,
    pub failed_task_count: u64,
    pub candidate_output_bytes_scored_total: u64,
    pub fixture_payload_bytes_persisted: u64,
    pub raw_prompt_bytes_captured: u64,
    pub raw_context_bytes_captured: u64,
    pub raw_output_bytes_captured: u64,
    pub raw_judge_bytes_captured: u64,
    pub runtime_router_mutation_count: u64,
    pub system_g_mutation_count: u64,
    pub settings_default_mutation_count: u64,
    pub route_admission_packet_ready: bool,
    pub quality_claim: bool,
    pub live_gemma_claim: bool,
    pub l2_l3_t4_claim: bool,
    pub live_dense_70b_claim: bool,
    pub reviewer_visible_summary: String,
    pub quality_summary_digest: String,
    pub failure_taxonomy_digest: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub non_promotion_ref: String,
    pub metadata_bytes: u64,
    pub next_cursor: String,
    pub artifact_digest: String,
}

#[derive(Debug)]
pub enum GemmaFirstRuntimeQualityReplayExecutionError {
    QualityPacket(GemmaFirstRuntimeQualityPacketMaterializerError),
    MissingTaskFamily,
    DuplicateTaskFamily,
    ObservationMismatch(&'static str),
    ArtifactInvalid(&'static str),
    Serialize(serde_json::Error),
}

impl fmt::Display for GemmaFirstRuntimeQualityReplayExecutionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::QualityPacket(error) => write!(f, "quality packet invalid: {error}"),
            Self::MissingTaskFamily => write!(f, "quality replay observations are incomplete"),
            Self::DuplicateTaskFamily => write!(
                f,
                "quality replay observations contain duplicate task families"
            ),
            Self::ObservationMismatch(field) => {
                write!(f, "quality replay observation mismatch: {field}")
            }
            Self::ArtifactInvalid(field) => write!(f, "quality replay artifact invalid: {field}"),
            Self::Serialize(error) => write!(f, "quality replay serialization error: {error}"),
        }
    }
}

impl std::error::Error for GemmaFirstRuntimeQualityReplayExecutionError {}

impl From<GemmaFirstRuntimeQualityPacketMaterializerError>
    for GemmaFirstRuntimeQualityReplayExecutionError
{
    fn from(value: GemmaFirstRuntimeQualityPacketMaterializerError) -> Self {
        Self::QualityPacket(value)
    }
}

impl From<serde_json::Error> for GemmaFirstRuntimeQualityReplayExecutionError {
    fn from(value: serde_json::Error) -> Self {
        Self::Serialize(value)
    }
}

pub fn execute_first_runtime_quality_replay(
    request: &GemmaFirstRuntimeQualityReplayRequest,
) -> Result<GemmaFirstRuntimeQualityReplayArtifact, GemmaFirstRuntimeQualityReplayExecutionError> {
    validate_first_runtime_quality_packet(&request.quality_packet)?;
    if request.quality_packet.next_cursor
        != GEMMA_FIRST_RUNTIME_QUALITY_PACKET_MATERIALIZER_NEXT_CURSOR
    {
        return Err(
            GemmaFirstRuntimeQualityReplayExecutionError::ObservationMismatch(
                "quality_packet.next_cursor",
            ),
        );
    }

    validate_observations_against_packet(&request.observations, &request.quality_packet)?;
    let mut task_results = request
        .observations
        .iter()
        .map(score_observation)
        .collect::<Vec<_>>();
    task_results.sort_by_key(|result| result.task_family);

    let passed_task_count = task_results.iter().filter(|result| result.passed).count() as u64;
    let failed_task_count = task_results.len() as u64 - passed_task_count;
    let candidate_output_bytes_scored_total = request
        .observations
        .iter()
        .map(|observation| observation.candidate_output.len() as u64)
        .sum();
    let route_admission_packet_ready = failed_task_count == 0;

    let mut artifact = GemmaFirstRuntimeQualityReplayArtifact {
        schema_version: GEMMA_FIRST_RUNTIME_QUALITY_REPLAY_EXECUTION_GATE_SCHEMA_VERSION
            .to_string(),
        upstream_quality_packet_digest: request.quality_packet.packet_digest.clone(),
        selected_model_id: request.quality_packet.selected_model_id.clone(),
        model_identity_digest: request.quality_packet.model_identity_digest.clone(),
        llama_cli_identity_digest: request.quality_packet.llama_cli_identity_digest.clone(),
        same_fixture_pack_digest: request.quality_packet.same_fixture_pack_digest.clone(),
        scorer_bundle_digest: request.quality_packet.scorer_bundle_digest.clone(),
        task_family_digest: request.quality_packet.task_family_digest.clone(),
        task_results,
        quality_replay_performed_count: 1,
        scorer_executions: request.observations.len() as u64,
        passed_task_count,
        failed_task_count,
        candidate_output_bytes_scored_total,
        fixture_payload_bytes_persisted: 0,
        raw_prompt_bytes_captured: 0,
        raw_context_bytes_captured: 0,
        raw_output_bytes_captured: 0,
        raw_judge_bytes_captured: 0,
        runtime_router_mutation_count: 0,
        system_g_mutation_count: 0,
        settings_default_mutation_count: 0,
        route_admission_packet_ready,
        quality_claim: false,
        live_gemma_claim: false,
        l2_l3_t4_claim: false,
        live_dense_70b_claim: false,
        reviewer_visible_summary: if route_admission_packet_ready {
            "Gemma first-runtime same-fixture replay passed deterministic shape/safety scoring; route admission remains a separate gated packet and no product quality claim is made."
        } else {
            "Gemma first-runtime same-fixture replay completed with deterministic task failures; route admission remains blocked."
        }
        .to_string(),
        quality_summary_digest: String::new(),
        failure_taxonomy_digest: String::new(),
        rollback_ref: "rollback:gemma-first-runtime-quality-replay-execution-v1".to_string(),
        run_event_log_ref: "run_event_log:gemma-first-runtime-quality-replay-execution-v1"
            .to_string(),
        answer_packet_ref: "answer_packet:gemma-first-runtime-quality-replay-execution-v1"
            .to_string(),
        abstention_ref: "abstention:gemma-first-runtime-quality-replay-execution-v1".to_string(),
        non_promotion_ref: "non_promotion:gemma-first-runtime-quality-replay-execution-v1"
            .to_string(),
        metadata_bytes: 96 * 1024,
        next_cursor: GEMMA_FIRST_RUNTIME_QUALITY_REPLAY_EXECUTION_GATE_NEXT_CURSOR.to_string(),
        artifact_digest: String::new(),
    };
    artifact.quality_summary_digest = quality_summary_digest(&artifact)?;
    artifact.failure_taxonomy_digest = failure_taxonomy_digest(&artifact)?;
    artifact.artifact_digest = first_runtime_quality_replay_artifact_digest(&artifact)?;
    validate_first_runtime_quality_replay_artifact(&artifact)?;
    Ok(artifact)
}

pub fn validate_first_runtime_quality_replay_artifact(
    artifact: &GemmaFirstRuntimeQualityReplayArtifact,
) -> Result<(), GemmaFirstRuntimeQualityReplayExecutionError> {
    if artifact.schema_version != GEMMA_FIRST_RUNTIME_QUALITY_REPLAY_EXECUTION_GATE_SCHEMA_VERSION {
        return Err(
            GemmaFirstRuntimeQualityReplayExecutionError::ArtifactInvalid("schema_version"),
        );
    }
    for (field, value) in [
        (
            "upstream_quality_packet_digest",
            &artifact.upstream_quality_packet_digest,
        ),
        ("model_identity_digest", &artifact.model_identity_digest),
        (
            "llama_cli_identity_digest",
            &artifact.llama_cli_identity_digest,
        ),
        ("task_family_digest", &artifact.task_family_digest),
        ("quality_summary_digest", &artifact.quality_summary_digest),
        ("failure_taxonomy_digest", &artifact.failure_taxonomy_digest),
        ("artifact_digest", &artifact.artifact_digest),
    ] {
        if !value.starts_with("sha256:") {
            return Err(GemmaFirstRuntimeQualityReplayExecutionError::ArtifactInvalid(field));
        }
    }
    if !artifact
        .same_fixture_pack_digest
        .starts_with("fixture_pack:sha256:")
        || !artifact
            .scorer_bundle_digest
            .starts_with("scorer_bundle:sha256:")
    {
        return Err(
            GemmaFirstRuntimeQualityReplayExecutionError::ArtifactInvalid(
                "fixture_or_scorer_digest",
            ),
        );
    }
    if artifact.quality_replay_performed_count != 1
        || artifact.scorer_executions != artifact.task_results.len() as u64
        || artifact.passed_task_count + artifact.failed_task_count
            != artifact.task_results.len() as u64
        || artifact.route_admission_packet_ready != (artifact.failed_task_count == 0)
        || artifact.fixture_payload_bytes_persisted != 0
        || artifact.raw_prompt_bytes_captured != 0
        || artifact.raw_context_bytes_captured != 0
        || artifact.raw_output_bytes_captured != 0
        || artifact.raw_judge_bytes_captured != 0
        || artifact.runtime_router_mutation_count != 0
        || artifact.system_g_mutation_count != 0
        || artifact.settings_default_mutation_count != 0
        || artifact.quality_claim
        || artifact.live_gemma_claim
        || artifact.l2_l3_t4_claim
        || artifact.live_dense_70b_claim
        || artifact.metadata_bytes > MAX_REPLAY_METADATA_BYTES
        || artifact.next_cursor != GEMMA_FIRST_RUNTIME_QUALITY_REPLAY_EXECUTION_GATE_NEXT_CURSOR
    {
        return Err(
            GemmaFirstRuntimeQualityReplayExecutionError::ArtifactInvalid("policy violation"),
        );
    }
    validate_task_result_coverage(&artifact.task_results)?;
    if artifact.quality_summary_digest != quality_summary_digest(artifact)? {
        return Err(
            GemmaFirstRuntimeQualityReplayExecutionError::ArtifactInvalid("quality_summary_digest"),
        );
    }
    if artifact.failure_taxonomy_digest != failure_taxonomy_digest(artifact)? {
        return Err(
            GemmaFirstRuntimeQualityReplayExecutionError::ArtifactInvalid(
                "failure_taxonomy_digest",
            ),
        );
    }
    if artifact.artifact_digest != first_runtime_quality_replay_artifact_digest(artifact)? {
        return Err(
            GemmaFirstRuntimeQualityReplayExecutionError::ArtifactInvalid("artifact_digest"),
        );
    }
    Ok(())
}

pub fn first_runtime_quality_replay_artifact_json_pretty(
    artifact: &GemmaFirstRuntimeQualityReplayArtifact,
) -> Result<Vec<u8>, GemmaFirstRuntimeQualityReplayExecutionError> {
    validate_first_runtime_quality_replay_artifact(artifact)?;
    let mut bytes = serde_json::to_vec_pretty(artifact)?;
    bytes.push(b'\n');
    Ok(bytes)
}

impl GemmaFirstRuntimeQualityReplayArtifact {
    pub fn replay_artifact_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_FIRST_RUNTIME_QUALITY_REPLAY_EXECUTION_GATE_CURSOR.to_string()),
            self.artifact_digest.as_bytes(),
            created_at_ms,
        )
    }
}

fn validate_observations_against_packet(
    observations: &[GemmaFirstRuntimeQualityTaskObservation],
    packet: &GemmaFirstRuntimeQualityPacket,
) -> Result<(), GemmaFirstRuntimeQualityReplayExecutionError> {
    let expected_families = packet
        .task_packets
        .iter()
        .map(|task| task.task_family)
        .collect::<BTreeSet<_>>();
    let actual_families = observations
        .iter()
        .map(|observation| observation.task_family)
        .collect::<BTreeSet<_>>();
    if observations.len() != actual_families.len() {
        return Err(GemmaFirstRuntimeQualityReplayExecutionError::DuplicateTaskFamily);
    }
    if expected_families != actual_families {
        return Err(GemmaFirstRuntimeQualityReplayExecutionError::MissingTaskFamily);
    }
    for observation in observations {
        let Some(packet_task) = packet
            .task_packets
            .iter()
            .find(|task| task.task_family == observation.task_family)
        else {
            return Err(GemmaFirstRuntimeQualityReplayExecutionError::MissingTaskFamily);
        };
        if packet_task.task_descriptor_digest != observation.task_descriptor_digest {
            return Err(
                GemmaFirstRuntimeQualityReplayExecutionError::ObservationMismatch(
                    "task_descriptor_digest",
                ),
            );
        }
        if packet_task.expected_output_shape_digest != observation.expected_output_shape_digest {
            return Err(
                GemmaFirstRuntimeQualityReplayExecutionError::ObservationMismatch(
                    "expected_output_shape_digest",
                ),
            );
        }
        if !observation.fixture_prompt_digest.starts_with("sha256:") {
            return Err(
                GemmaFirstRuntimeQualityReplayExecutionError::ObservationMismatch(
                    "fixture_prompt_digest",
                ),
            );
        }
    }
    Ok(())
}

fn validate_task_result_coverage(
    results: &[GemmaFirstRuntimeQualityTaskReplayResult],
) -> Result<(), GemmaFirstRuntimeQualityReplayExecutionError> {
    let families = results
        .iter()
        .map(|result| result.task_family)
        .collect::<BTreeSet<_>>();
    if results.len() != families.len() || results.len() != 7 {
        return Err(GemmaFirstRuntimeQualityReplayExecutionError::MissingTaskFamily);
    }
    for result in results {
        for (field, value) in [
            ("task_descriptor_digest", &result.task_descriptor_digest),
            (
                "expected_output_shape_digest",
                &result.expected_output_shape_digest,
            ),
            ("fixture_prompt_digest", &result.fixture_prompt_digest),
            ("candidate_output_digest", &result.candidate_output_digest),
            (
                "redacted_output_shape_digest",
                &result.redacted_output_shape_digest,
            ),
            (
                "deterministic_scorer_digest",
                &result.deterministic_scorer_digest,
            ),
            ("exit_status_digest", &result.exit_status_digest),
        ] {
            if !value.starts_with("sha256:") {
                return Err(GemmaFirstRuntimeQualityReplayExecutionError::ArtifactInvalid(field));
            }
        }
        if result.score > 100 || result.passed != result.failure_codes.is_empty() {
            return Err(
                GemmaFirstRuntimeQualityReplayExecutionError::ArtifactInvalid("task_result"),
            );
        }
    }
    Ok(())
}

fn score_observation(
    observation: &GemmaFirstRuntimeQualityTaskObservation,
) -> GemmaFirstRuntimeQualityTaskReplayResult {
    let mut failure_codes = Vec::new();
    let output = observation.candidate_output.trim();
    let lower = output.to_ascii_lowercase();
    let byte_count = observation.candidate_output.len();
    let word_count = output.split_whitespace().count();
    let line_count = output.lines().count().max(1);
    let json_valid = serde_json::from_str::<serde_json::Value>(output).is_ok();

    if output.is_empty() {
        failure_codes.push("empty_output".to_string());
    }
    if byte_count > MAX_TASK_OUTPUT_BYTES {
        failure_codes.push("output_too_large".to_string());
    }
    if observation.timed_out {
        failure_codes.push("timed_out".to_string());
    }
    if observation.exit_code != 0 {
        failure_codes.push("nonzero_exit".to_string());
    }
    if !observation.cache_deleted_before_replay {
        failure_codes.push("cache_not_deleted".to_string());
    }
    if !observation.contamination_check_passed {
        failure_codes.push("contamination_check_failed".to_string());
    }

    match observation.task_family {
        GemmaQatQualityTaskFamily::NoteSynthesis => {
            if word_count < 12 {
                failure_codes.push("note_synthesis_too_short".to_string());
            }
        }
        GemmaQatQualityTaskFamily::CitationGroundedResearch => {
            if word_count < 15
                || !(output.contains('[') && output.contains(']') || lower.contains("source:"))
            {
                failure_codes.push("citation_grounding_shape_missing".to_string());
            }
        }
        GemmaQatQualityTaskFamily::StructuredToolJson => {
            if !json_valid {
                failure_codes.push("structured_json_invalid".to_string());
            }
        }
        GemmaQatQualityTaskFamily::CacheDeletionReuse => {
            if !(lower.contains("cache") || lower.contains("fresh") || lower.contains("reuse")) {
                failure_codes.push("cache_reuse_language_missing".to_string());
            }
        }
        GemmaQatQualityTaskFamily::WritingEdit => {
            if word_count < 10 {
                failure_codes.push("writing_edit_too_short".to_string());
            }
        }
        GemmaQatQualityTaskFamily::CodingPatch => {
            if !(output.contains("```")
                || lower.contains("diff")
                || output.contains("@@")
                || lower.contains("file"))
            {
                failure_codes.push("coding_patch_shape_missing".to_string());
            }
        }
        GemmaQatQualityTaskFamily::RefusalAbstention => {
            if !(lower.contains("cannot")
                || lower.contains("can't")
                || lower.contains("unable")
                || lower.contains("privacy")
                || lower.contains("abstain"))
            {
                failure_codes.push("refusal_abstention_shape_missing".to_string());
            }
        }
    }

    let score = if failure_codes.is_empty() { 100 } else { 0 };
    let shape_preimage = serde_json::json!({
        "task_family": observation.task_family,
        "byte_count": byte_count,
        "word_count": word_count,
        "line_count": line_count,
        "json_valid": json_valid,
        "timed_out": observation.timed_out,
        "exit_code": observation.exit_code,
    });
    let scorer_preimage = serde_json::json!({
        "scorer": "gemma-first-runtime-shape-safety-scorer-v1",
        "task_family": observation.task_family,
        "score": score,
        "failure_codes": failure_codes,
    });
    GemmaFirstRuntimeQualityTaskReplayResult {
        task_family: observation.task_family,
        task_descriptor_digest: observation.task_descriptor_digest.clone(),
        expected_output_shape_digest: observation.expected_output_shape_digest.clone(),
        fixture_prompt_digest: observation.fixture_prompt_digest.clone(),
        candidate_output_digest: sha256_hex(observation.candidate_output.as_bytes()),
        redacted_output_shape_digest: sha256_hex(shape_preimage.to_string().as_bytes()),
        deterministic_scorer_digest: sha256_hex(scorer_preimage.to_string().as_bytes()),
        score,
        passed: failure_codes.is_empty(),
        failure_codes,
        duration_ms: observation.duration_ms,
        exit_status_digest: sha256_hex(
            format!(
                "{}|{}|{}",
                observation.exit_code, observation.timed_out, observation.duration_ms
            )
            .as_bytes(),
        ),
    }
}

fn quality_summary_digest(
    artifact: &GemmaFirstRuntimeQualityReplayArtifact,
) -> Result<String, GemmaFirstRuntimeQualityReplayExecutionError> {
    Ok(sha256_hex(&serde_json::to_vec(&serde_json::json!({
        "passed_task_count": artifact.passed_task_count,
        "failed_task_count": artifact.failed_task_count,
        "route_admission_packet_ready": artifact.route_admission_packet_ready,
        "task_results": artifact
            .task_results
            .iter()
            .map(|result| serde_json::json!({
                "task_family": result.task_family,
                "score": result.score,
                "passed": result.passed,
                "failure_codes": result.failure_codes,
                "candidate_output_digest": result.candidate_output_digest,
            }))
            .collect::<Vec<_>>(),
    }))?))
}

fn failure_taxonomy_digest(
    artifact: &GemmaFirstRuntimeQualityReplayArtifact,
) -> Result<String, GemmaFirstRuntimeQualityReplayExecutionError> {
    let failures = artifact
        .task_results
        .iter()
        .flat_map(|result| {
            result
                .failure_codes
                .iter()
                .map(|code| format!("{:?}:{code}", result.task_family))
                .collect::<Vec<_>>()
        })
        .collect::<Vec<_>>();
    Ok(sha256_hex(&serde_json::to_vec(&failures)?))
}

fn first_runtime_quality_replay_artifact_digest(
    artifact: &GemmaFirstRuntimeQualityReplayArtifact,
) -> Result<String, GemmaFirstRuntimeQualityReplayExecutionError> {
    let mut clone = artifact.clone();
    clone.artifact_digest.clear();
    Ok(sha256_hex(&serde_json::to_vec(&clone)?))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{
        build_first_runtime_execution_receipt, build_receipt_from_observed_material,
        materialize_first_runtime_quality_packet, GemmaFirstRuntimeExecutionObservation,
        GemmaFirstRuntimeExecutionProbeRequest, GemmaFirstRuntimeQualityPacketRequest,
        GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest,
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

    fn passing_observations(
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
                    GemmaQatQualityTaskFamily::CodingPatch => {
                        "```diff\n@@\n- old\n+ new\n```"
                    }
                    GemmaQatQualityTaskFamily::RefusalAbstention => {
                        "I cannot help with that private data request and will abstain unless permission is granted."
                    }
                };
                GemmaFirstRuntimeQualityTaskObservation {
                    task_family: task.task_family,
                    task_descriptor_digest: task.task_descriptor_digest.clone(),
                    expected_output_shape_digest: task.expected_output_shape_digest.clone(),
                    fixture_prompt_digest: sha256_hex(format!("{:?}:prompt", task.task_family).as_bytes()),
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

    #[test]
    fn executes_digest_only_shape_safety_replay_for_all_task_families() {
        let packet = quality_packet();
        let artifact =
            execute_first_runtime_quality_replay(&GemmaFirstRuntimeQualityReplayRequest {
                observations: passing_observations(&packet),
                quality_packet: packet,
            })
            .expect("replay artifact");

        validate_first_runtime_quality_replay_artifact(&artifact).expect("valid replay");
        assert_eq!(artifact.scorer_executions, 7);
        assert_eq!(artifact.passed_task_count, 7);
        assert_eq!(artifact.failed_task_count, 0);
        assert!(artifact.route_admission_packet_ready);
        assert!(!artifact.quality_claim);
        assert_eq!(
            artifact.next_cursor,
            GEMMA_FIRST_RUNTIME_QUALITY_REPLAY_EXECUTION_GATE_NEXT_CURSOR
        );
    }

    #[test]
    fn pretty_json_excludes_raw_candidate_output() {
        let packet = quality_packet();
        let artifact =
            execute_first_runtime_quality_replay(&GemmaFirstRuntimeQualityReplayRequest {
                observations: passing_observations(&packet),
                quality_packet: packet,
            })
            .expect("replay artifact");
        let json = String::from_utf8(
            first_runtime_quality_replay_artifact_json_pretty(&artifact).unwrap(),
        )
        .expect("utf8");

        assert!(json.contains("candidate_output_digest"));
        assert!(!json.contains("This note synthesis combines"));
        assert!(!json.contains("Return exactly OK."));
        assert!(!json.contains("/Users/jojo/private"));
    }

    #[test]
    fn rejects_missing_or_duplicate_task_family() {
        let packet = quality_packet();
        let mut observations = passing_observations(&packet);
        observations.pop();
        assert!(matches!(
            execute_first_runtime_quality_replay(&GemmaFirstRuntimeQualityReplayRequest {
                observations,
                quality_packet: packet.clone(),
            }),
            Err(GemmaFirstRuntimeQualityReplayExecutionError::MissingTaskFamily)
        ));

        let mut observations = passing_observations(&packet);
        observations[1].task_family = observations[0].task_family;
        assert!(matches!(
            execute_first_runtime_quality_replay(&GemmaFirstRuntimeQualityReplayRequest {
                observations,
                quality_packet: packet,
            }),
            Err(GemmaFirstRuntimeQualityReplayExecutionError::DuplicateTaskFamily)
        ));
    }

    #[test]
    fn task_failures_block_route_admission_without_claiming_quality() {
        let packet = quality_packet();
        let mut observations = passing_observations(&packet);
        observations
            .iter_mut()
            .find(|observation| {
                observation.task_family == GemmaQatQualityTaskFamily::StructuredToolJson
            })
            .expect("json task")
            .candidate_output = "not json".to_string();

        let artifact =
            execute_first_runtime_quality_replay(&GemmaFirstRuntimeQualityReplayRequest {
                observations,
                quality_packet: packet,
            })
            .expect("replay artifact");
        assert_eq!(artifact.failed_task_count, 1);
        assert!(!artifact.route_admission_packet_ready);
        assert!(!artifact.quality_claim);
    }
}
