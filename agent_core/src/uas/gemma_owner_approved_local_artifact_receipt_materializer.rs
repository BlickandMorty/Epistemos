//! Owner-approved Gemma local artifact receipt materializer.
//!
//! This is the first non-metadata receipt step. It only runs when an owner
//! supplies one explicit local artifact path plus an approval phrase. It hashes
//! that single file, redacts the path to a digest, binds `llama-cli` identity
//! with `--version` and `--help`, and emits no route or runtime mutation.

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fmt;
use std::fs::File;
use std::io::{self, Read};
use std::path::{Path, PathBuf};
use std::process::Command;

use crate::falsifier_artifacts::sha256_hex;

pub const GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_MATERIALIZER_CURSOR: &str =
    "gemma_owner_approved_local_artifact_receipt_materializer";
pub const GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_MATERIALIZER_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_first_runtime_execution_probe";
pub const GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_MATERIALIZER_COMMAND_CARD_ID: &str =
    "F-GemmaDirectHarnessFirstRuntimeProofCommandCard";
pub const GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_SCHEMA_VERSION: &str =
    "gemma-owner-approved-local-artifact-receipt-v1";

const GGUF_RUNTIME_LANE: &str = "gguf_llama_cpp_offline";
const GGUF_FILE_TYPE: &str = "gguf";

const ALLOWED_GGUF_MODEL_IDS: &[&str] = &[
    "google/gemma-4-E2B-it-qat-q4_0-gguf",
    "google/gemma-4-E4B-it-qat-q4_0-gguf",
    "google/gemma-4-12B-it-qat-q4_0-gguf",
];

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest {
    pub owner_approval_phrase: String,
    pub local_file_path: PathBuf,
    pub selected_model_id: String,
    pub source_repo: String,
    pub source_revision: String,
    pub expected_filename: String,
    pub expected_byte_count: u64,
    pub expected_file_sha256: String,
    pub source_license_ref: String,
    pub provenance_mode: String,
    pub hardware_profile_ref: String,
    pub llama_cli_path: PathBuf,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaOwnerApprovedLocalArtifactReceipt {
    pub schema_version: String,
    pub owner_approval_phrase_digest: String,
    pub selected_model_id: String,
    pub model_family: String,
    pub source_repo: String,
    pub source_revision: String,
    pub expected_filename: String,
    pub expected_byte_count: u64,
    pub expected_file_sha256: String,
    pub observed_byte_count: u64,
    pub observed_byte_count_matches_expected: bool,
    pub local_file_sha256: String,
    pub local_file_sha256_matches_expected: bool,
    pub redacted_path_digest: String,
    pub raw_path_absent: bool,
    pub file_type: String,
    pub runtime_lane: String,
    pub selected_command_card_id: String,
    pub llama_cli_version_digest: String,
    pub llama_cli_help_digest: String,
    pub llama_cli_version_status_success: bool,
    pub llama_cli_help_status_success: bool,
    pub offline_flag_present: bool,
    pub source_license_ref: String,
    pub provenance_mode: String,
    pub hardware_profile_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub reviewer_visible_summary: String,
    pub non_promotion_ref: String,
    pub runtime_router_mutation_count: u64,
    pub system_g_mutation_count: u64,
    pub settings_default_mutation_count: u64,
    pub runtime_command_executed_count: u64,
    pub server_started_count: u64,
    pub network_probe_count: u64,
    pub model_bytes_loaded: u64,
    pub quality_claim: bool,
    pub live_gemma_claim: bool,
    pub l2_l3_t4_claim: bool,
    pub live_dense_70b_claim: bool,
    pub next_cursor: String,
    pub receipt_digest: String,
}

#[derive(Debug)]
pub enum GemmaOwnerApprovedLocalArtifactReceiptMaterializerError {
    MissingField(&'static str),
    UnsupportedModel(String),
    ExpectedFilenameMismatch {
        expected: String,
        observed: String,
    },
    ExpectedByteCountMismatch {
        expected: u64,
        observed: u64,
    },
    ExpectedFileSha256Mismatch {
        expected: String,
        observed: String,
    },
    FileTypeMismatch(String),
    FileIo(io::Error),
    ToolIo {
        tool: &'static str,
        source: io::Error,
    },
    LlamaCliVersionFailed,
    LlamaCliHelpFailed,
    OfflineFlagMissing,
    ReceiptInvalid(&'static str),
    Serialize(serde_json::Error),
}

impl fmt::Display for GemmaOwnerApprovedLocalArtifactReceiptMaterializerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "{field} is missing"),
            Self::UnsupportedModel(model) => write!(f, "unsupported model id: {model}"),
            Self::ExpectedFilenameMismatch { expected, observed } => {
                write!(f, "expected filename {expected}, observed {observed}")
            }
            Self::ExpectedByteCountMismatch { expected, observed } => {
                write!(f, "expected byte count {expected}, observed {observed}")
            }
            Self::ExpectedFileSha256Mismatch { expected, observed } => {
                write!(f, "expected file sha256 {expected}, observed {observed}")
            }
            Self::FileTypeMismatch(filename) => write!(f, "expected .gguf file: {filename}"),
            Self::FileIo(error) => write!(f, "file io error: {error}"),
            Self::ToolIo { tool, source } => write!(f, "{tool} io error: {source}"),
            Self::LlamaCliVersionFailed => write!(f, "llama-cli --version failed"),
            Self::LlamaCliHelpFailed => write!(f, "llama-cli --help failed"),
            Self::OfflineFlagMissing => write!(f, "llama-cli --help did not expose --offline"),
            Self::ReceiptInvalid(reason) => write!(f, "receipt invalid: {reason}"),
            Self::Serialize(error) => write!(f, "receipt serialization error: {error}"),
        }
    }
}

impl std::error::Error for GemmaOwnerApprovedLocalArtifactReceiptMaterializerError {}

impl From<io::Error> for GemmaOwnerApprovedLocalArtifactReceiptMaterializerError {
    fn from(value: io::Error) -> Self {
        Self::FileIo(value)
    }
}

impl From<serde_json::Error> for GemmaOwnerApprovedLocalArtifactReceiptMaterializerError {
    fn from(value: serde_json::Error) -> Self {
        Self::Serialize(value)
    }
}

impl GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest {
    pub fn validate(&self) -> Result<(), GemmaOwnerApprovedLocalArtifactReceiptMaterializerError> {
        validate_nonempty("owner_approval_phrase", &self.owner_approval_phrase)?;
        validate_nonempty("selected_model_id", &self.selected_model_id)?;
        validate_nonempty("source_repo", &self.source_repo)?;
        validate_nonempty("source_revision", &self.source_revision)?;
        validate_nonempty("expected_filename", &self.expected_filename)?;
        validate_nonempty("expected_file_sha256", &self.expected_file_sha256)?;
        validate_nonempty("source_license_ref", &self.source_license_ref)?;
        validate_nonempty("provenance_mode", &self.provenance_mode)?;
        validate_nonempty("hardware_profile_ref", &self.hardware_profile_ref)?;
        if !ALLOWED_GGUF_MODEL_IDS.contains(&self.selected_model_id.as_str()) {
            return Err(
                GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::UnsupportedModel(
                    self.selected_model_id.clone(),
                ),
            );
        }
        if self.expected_byte_count == 0 {
            return Err(
                GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::MissingField(
                    "expected_byte_count",
                ),
            );
        }
        normalize_sha256_digest(&self.expected_file_sha256)?;
        Ok(())
    }
}

pub fn materialize_owner_approved_local_artifact_receipt(
    request: &GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest,
) -> Result<
    GemmaOwnerApprovedLocalArtifactReceipt,
    GemmaOwnerApprovedLocalArtifactReceiptMaterializerError,
> {
    request.validate()?;

    let observed_filename = request
        .local_file_path
        .file_name()
        .and_then(|value| value.to_str())
        .ok_or(
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::MissingField(
                "local_file_path.file_name",
            ),
        )?
        .to_string();
    if observed_filename != request.expected_filename {
        return Err(
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::ExpectedFilenameMismatch {
                expected: request.expected_filename.clone(),
                observed: observed_filename,
            },
        );
    }
    if !request
        .expected_filename
        .to_ascii_lowercase()
        .ends_with(".gguf")
    {
        return Err(
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::FileTypeMismatch(
                request.expected_filename.clone(),
            ),
        );
    }

    let observed_byte_count = std::fs::metadata(&request.local_file_path)?.len();
    if observed_byte_count != request.expected_byte_count {
        return Err(
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::ExpectedByteCountMismatch {
                expected: request.expected_byte_count,
                observed: observed_byte_count,
            },
        );
    }

    let local_file_sha256 = sha256_file(&request.local_file_path)?;
    let expected_file_sha256 = normalize_sha256_digest(&request.expected_file_sha256)?;
    if local_file_sha256 != expected_file_sha256 {
        return Err(
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::ExpectedFileSha256Mismatch {
                expected: expected_file_sha256,
                observed: local_file_sha256,
            },
        );
    }
    let llama_cli_identity = llama_cli_identity_for_path(&request.llama_cli_path)?;
    if !llama_cli_identity.version_status_success {
        return Err(GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::LlamaCliVersionFailed);
    }
    if !llama_cli_identity.help_status_success {
        return Err(GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::LlamaCliHelpFailed);
    }
    if !llama_cli_identity.offline_flag_present {
        return Err(GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::OfflineFlagMissing);
    }

    build_receipt_from_observed_material(
        request,
        observed_byte_count,
        local_file_sha256,
        llama_cli_identity.version_digest,
        llama_cli_identity.help_digest,
        llama_cli_identity.version_status_success,
        llama_cli_identity.help_status_success,
        llama_cli_identity.offline_flag_present,
    )
}

pub fn build_receipt_from_observed_material(
    request: &GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest,
    observed_byte_count: u64,
    local_file_sha256: String,
    llama_cli_version_digest: String,
    llama_cli_help_digest: String,
    llama_cli_version_status_success: bool,
    llama_cli_help_status_success: bool,
    offline_flag_present: bool,
) -> Result<
    GemmaOwnerApprovedLocalArtifactReceipt,
    GemmaOwnerApprovedLocalArtifactReceiptMaterializerError,
> {
    request.validate()?;
    if observed_byte_count != request.expected_byte_count {
        return Err(
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::ExpectedByteCountMismatch {
                expected: request.expected_byte_count,
                observed: observed_byte_count,
            },
        );
    }
    let expected_file_sha256 = normalize_sha256_digest(&request.expected_file_sha256)?;
    if local_file_sha256 != expected_file_sha256 {
        return Err(
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::ExpectedFileSha256Mismatch {
                expected: expected_file_sha256,
                observed: local_file_sha256,
            },
        );
    }
    if !offline_flag_present {
        return Err(GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::OfflineFlagMissing);
    }

    let mut receipt = GemmaOwnerApprovedLocalArtifactReceipt {
        schema_version: GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_SCHEMA_VERSION.to_string(),
        owner_approval_phrase_digest: sha256_hex(request.owner_approval_phrase.as_bytes()),
        selected_model_id: request.selected_model_id.clone(),
        model_family: "gemma-4-qat".to_string(),
        source_repo: request.source_repo.clone(),
        source_revision: request.source_revision.clone(),
        expected_filename: request.expected_filename.clone(),
        expected_byte_count: request.expected_byte_count,
        expected_file_sha256,
        observed_byte_count,
        observed_byte_count_matches_expected: observed_byte_count == request.expected_byte_count,
        local_file_sha256,
        local_file_sha256_matches_expected: true,
        redacted_path_digest: redacted_path_digest_for_path(&request.local_file_path),
        raw_path_absent: true,
        file_type: GGUF_FILE_TYPE.to_string(),
        runtime_lane: GGUF_RUNTIME_LANE.to_string(),
        selected_command_card_id:
            GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_MATERIALIZER_COMMAND_CARD_ID.to_string(),
        llama_cli_version_digest,
        llama_cli_help_digest,
        llama_cli_version_status_success,
        llama_cli_help_status_success,
        offline_flag_present,
        source_license_ref: request.source_license_ref.clone(),
        provenance_mode: request.provenance_mode.clone(),
        hardware_profile_ref: request.hardware_profile_ref.clone(),
        rollback_ref: "rollback:gemma-owner-approved-local-artifact-receipt-materializer-v1"
            .to_string(),
        run_event_log_ref:
            "run_event_log:gemma-owner-approved-local-artifact-receipt-materializer-v1"
                .to_string(),
        answer_packet_ref:
            "answer_packet:gemma-owner-approved-local-artifact-receipt-materializer-v1"
                .to_string(),
        abstention_ref:
            "abstention:gemma-owner-approved-local-artifact-receipt-materializer-v1"
                .to_string(),
        reviewer_visible_summary:
            "Owner-approved local Gemma GGUF receipt materialized: file/path are redacted to digests; no model execution, route mutation, quality claim, or user-facing Gemma promotion occurred."
                .to_string(),
        non_promotion_ref:
            "non_promotion:gemma-owner-approved-local-artifact-receipt-materializer-v1"
                .to_string(),
        runtime_router_mutation_count: 0,
        system_g_mutation_count: 0,
        settings_default_mutation_count: 0,
        runtime_command_executed_count: 0,
        server_started_count: 0,
        network_probe_count: 0,
        model_bytes_loaded: 0,
        quality_claim: false,
        live_gemma_claim: false,
        l2_l3_t4_claim: false,
        live_dense_70b_claim: false,
        next_cursor: GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_MATERIALIZER_NEXT_CURSOR
            .to_string(),
        receipt_digest: String::new(),
    };
    receipt.receipt_digest = receipt_digest(&receipt)?;
    validate_receipt(&receipt)?;
    Ok(receipt)
}

pub fn validate_receipt(
    receipt: &GemmaOwnerApprovedLocalArtifactReceipt,
) -> Result<(), GemmaOwnerApprovedLocalArtifactReceiptMaterializerError> {
    if receipt.schema_version != GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_SCHEMA_VERSION {
        return Err(
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::ReceiptInvalid(
                "bad schema_version",
            ),
        );
    }
    if !receipt.owner_approval_phrase_digest.starts_with("sha256:")
        || !receipt.local_file_sha256.starts_with("sha256:")
        || !receipt.expected_file_sha256.starts_with("sha256:")
        || !receipt.redacted_path_digest.starts_with("sha256:")
        || !receipt.llama_cli_version_digest.starts_with("sha256:")
        || !receipt.llama_cli_help_digest.starts_with("sha256:")
        || !receipt.receipt_digest.starts_with("sha256:")
    {
        return Err(
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::ReceiptInvalid(
                "missing digest prefix",
            ),
        );
    }
    if !ALLOWED_GGUF_MODEL_IDS.contains(&receipt.selected_model_id.as_str()) {
        return Err(
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::ReceiptInvalid(
                "unsupported selected_model_id",
            ),
        );
    }
    if receipt.local_file_sha256 != receipt.expected_file_sha256 {
        return Err(
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::ReceiptInvalid(
                "local_file_sha256 mismatch",
            ),
        );
    }
    if !receipt.raw_path_absent
        || !receipt.observed_byte_count_matches_expected
        || !receipt.local_file_sha256_matches_expected
        || receipt.runtime_lane != GGUF_RUNTIME_LANE
        || receipt.file_type != GGUF_FILE_TYPE
        || receipt.selected_command_card_id
            != GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_MATERIALIZER_COMMAND_CARD_ID
        || !receipt.llama_cli_version_status_success
        || !receipt.llama_cli_help_status_success
        || !receipt.offline_flag_present
        || receipt.runtime_router_mutation_count != 0
        || receipt.system_g_mutation_count != 0
        || receipt.settings_default_mutation_count != 0
        || receipt.runtime_command_executed_count != 0
        || receipt.server_started_count != 0
        || receipt.network_probe_count != 0
        || receipt.model_bytes_loaded != 0
        || receipt.quality_claim
        || receipt.live_gemma_claim
        || receipt.l2_l3_t4_claim
        || receipt.live_dense_70b_claim
        || receipt.next_cursor
            != GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_MATERIALIZER_NEXT_CURSOR
    {
        return Err(
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::ReceiptInvalid(
                "policy violation",
            ),
        );
    }
    if receipt.receipt_digest != receipt_digest(receipt)? {
        return Err(
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::ReceiptInvalid(
                "receipt_digest mismatch",
            ),
        );
    }
    Ok(())
}

pub fn receipt_json_pretty(
    receipt: &GemmaOwnerApprovedLocalArtifactReceipt,
) -> Result<Vec<u8>, GemmaOwnerApprovedLocalArtifactReceiptMaterializerError> {
    validate_receipt(receipt)?;
    let mut bytes = serde_json::to_vec_pretty(receipt)?;
    bytes.push(b'\n');
    Ok(bytes)
}

pub fn sha256_file(
    path: &Path,
) -> Result<String, GemmaOwnerApprovedLocalArtifactReceiptMaterializerError> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0_u8; 1024 * 1024];
    loop {
        let n = file.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        hasher.update(&buffer[..n]);
    }
    Ok(format!("sha256:{}", hex_lower(&hasher.finalize())))
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GemmaLlamaCliIdentityDigest {
    pub version_digest: String,
    pub help_digest: String,
    pub version_status_success: bool,
    pub help_status_success: bool,
    pub offline_flag_present: bool,
}

pub fn llama_cli_identity_for_path(
    path: &Path,
) -> Result<GemmaLlamaCliIdentityDigest, GemmaOwnerApprovedLocalArtifactReceiptMaterializerError> {
    let version = tool_output_digest(path, &["--version"], "llama-cli --version")?;
    let help = tool_output_digest(path, &["--help"], "llama-cli --help")?;
    Ok(GemmaLlamaCliIdentityDigest {
        version_digest: version.digest,
        help_digest: help.digest,
        version_status_success: version.status_success,
        help_status_success: help.status_success,
        offline_flag_present: help.contains_offline_flag,
    })
}

pub fn redacted_path_digest_for_path(path: &Path) -> String {
    sha256_hex(path_digest_bytes(path).as_slice())
}

struct ToolOutputDigest {
    digest: String,
    status_success: bool,
    contains_offline_flag: bool,
}

fn tool_output_digest(
    tool_path: &Path,
    args: &[&str],
    label: &'static str,
) -> Result<ToolOutputDigest, GemmaOwnerApprovedLocalArtifactReceiptMaterializerError> {
    let output = Command::new(tool_path)
        .args(args)
        .output()
        .map_err(
            |source| GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::ToolIo {
                tool: label,
                source,
            },
        )?;
    let mut bytes = Vec::new();
    bytes.extend_from_slice(format!("status:{}\nstdout:", output.status).as_bytes());
    bytes.extend_from_slice(&output.stdout);
    bytes.extend_from_slice(b"\nstderr:");
    bytes.extend_from_slice(&output.stderr);
    let contains_offline_flag = output
        .stdout
        .windows(b"--offline".len())
        .any(|w| w == b"--offline")
        || output
            .stderr
            .windows(b"--offline".len())
            .any(|w| w == b"--offline");
    Ok(ToolOutputDigest {
        digest: sha256_hex(&bytes),
        status_success: output.status.success(),
        contains_offline_flag,
    })
}

fn receipt_digest(
    receipt: &GemmaOwnerApprovedLocalArtifactReceipt,
) -> Result<String, GemmaOwnerApprovedLocalArtifactReceiptMaterializerError> {
    let mut clone = receipt.clone();
    clone.receipt_digest.clear();
    Ok(sha256_hex(&serde_json::to_vec(&clone)?))
}

fn path_digest_bytes(path: &Path) -> Vec<u8> {
    path.as_os_str().to_string_lossy().as_bytes().to_vec()
}

fn validate_nonempty(
    field: &'static str,
    value: &str,
) -> Result<(), GemmaOwnerApprovedLocalArtifactReceiptMaterializerError> {
    if value.trim().is_empty() {
        return Err(GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::MissingField(field));
    }
    Ok(())
}

fn normalize_sha256_digest(
    value: &str,
) -> Result<String, GemmaOwnerApprovedLocalArtifactReceiptMaterializerError> {
    let trimmed = value.trim();
    let hex = trimmed.strip_prefix("sha256:").unwrap_or(trimmed);
    if hex.len() != 64 || !hex.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err(
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::MissingField(
                "expected_file_sha256",
            ),
        );
    }
    Ok(format!("sha256:{}", hex.to_ascii_lowercase()))
}

fn hex_lower(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        out.push(HEX[(byte >> 4) as usize] as char);
        out.push(HEX[(byte & 0x0f) as usize] as char);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn request(path: &str) -> GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest {
        GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest {
            owner_approval_phrase: "owner explicitly approves this local Gemma receipt".to_string(),
            local_file_path: PathBuf::from(path),
            selected_model_id: "google/gemma-4-E2B-it-qat-q4_0-gguf".to_string(),
            source_repo: "google/gemma-4-E2B-it-qat-q4_0-gguf".to_string(),
            source_revision: "source-card-digest:fixture".to_string(),
            expected_filename: "gemma-fixture.gguf".to_string(),
            expected_byte_count: 12,
            expected_file_sha256: sha256_hex(b"model bytes"),
            source_license_ref: "license:gemma-terms".to_string(),
            provenance_mode: "owner_approved_direct_local_file".to_string(),
            hardware_profile_ref: "hardware:m2-pro-18gb-test".to_string(),
            llama_cli_path: PathBuf::from("llama-cli"),
        }
    }

    #[test]
    fn builds_digest_only_receipt_without_raw_path_or_route_mutation() {
        let req = request("/Users/jojo/secret/gemma-fixture.gguf");
        let receipt = build_receipt_from_observed_material(
            &req,
            12,
            sha256_hex(b"model bytes"),
            sha256_hex(b"llama-cli version"),
            sha256_hex(b"llama-cli help --offline"),
            true,
            true,
            true,
        )
        .expect("receipt");
        validate_receipt(&receipt).expect("valid receipt");

        let json = String::from_utf8(receipt_json_pretty(&receipt).unwrap()).unwrap();
        assert!(!json.contains("/Users/jojo/secret"));
        assert!(json.contains("redacted_path_digest"));
        assert_eq!(receipt.runtime_router_mutation_count, 0);
        assert_eq!(receipt.system_g_mutation_count, 0);
        assert!(!receipt.live_gemma_claim);
        assert_eq!(
            receipt.next_cursor,
            GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_MATERIALIZER_NEXT_CURSOR
        );
    }

    #[test]
    fn rejects_missing_owner_approval_phrase() {
        let mut req = request("gemma-fixture.gguf");
        req.owner_approval_phrase.clear();
        assert!(matches!(
            build_receipt_from_observed_material(
                &req,
                12,
                sha256_hex(b"model bytes"),
                sha256_hex(b"version"),
                sha256_hex(b"help"),
                true,
                true,
                true,
            )
            .unwrap_err(),
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::MissingField(
                "owner_approval_phrase"
            )
        ));
    }

    #[test]
    fn rejects_byte_count_mismatch() {
        let req = request("gemma-fixture.gguf");
        assert!(matches!(
            build_receipt_from_observed_material(
                &req,
                11,
                sha256_hex(b"model bytes"),
                sha256_hex(b"version"),
                sha256_hex(b"help"),
                true,
                true,
                true,
            )
            .unwrap_err(),
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::ExpectedByteCountMismatch {
                expected: 12,
                observed: 11
            }
        ));
    }

    #[test]
    fn rejects_sha256_mismatch() {
        let req = request("gemma-fixture.gguf");
        assert!(matches!(
            build_receipt_from_observed_material(
                &req,
                12,
                sha256_hex(b"different model bytes"),
                sha256_hex(b"version"),
                sha256_hex(b"help"),
                true,
                true,
                true,
            )
            .unwrap_err(),
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::ExpectedFileSha256Mismatch { .. }
        ));
    }

    #[test]
    fn accepts_official_twelve_b_qat_lane_as_flagship_receipt_subject() {
        let mut req = request("gemma-4-12b-it-qat-q4_0.gguf");
        req.selected_model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string();
        req.source_repo = req.selected_model_id.clone();
        req.expected_filename = "gemma-4-12b-it-qat-q4_0.gguf".to_string();
        let receipt = build_receipt_from_observed_material(
            &req,
            12,
            sha256_hex(b"model bytes"),
            sha256_hex(b"version"),
            sha256_hex(b"help --offline"),
            true,
            true,
            true,
        )
        .expect("12B receipt");
        validate_receipt(&receipt).expect("valid 12B receipt");
        assert_eq!(
            receipt.selected_model_id,
            "google/gemma-4-12B-it-qat-q4_0-gguf"
        );
        assert!(receipt.local_file_sha256_matches_expected);
    }

    #[test]
    fn rejects_missing_offline_flag() {
        let req = request("gemma-fixture.gguf");
        assert!(matches!(
            build_receipt_from_observed_material(
                &req,
                12,
                sha256_hex(b"model bytes"),
                sha256_hex(b"version"),
                sha256_hex(b"help"),
                true,
                true,
                false,
            )
            .unwrap_err(),
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::OfflineFlagMissing
        ));
    }

    #[test]
    fn rejects_unsupported_model() {
        let mut req = request("gemma-fixture.gguf");
        req.selected_model_id = "google/gemma-4-12B-it".to_string();
        assert!(matches!(
            build_receipt_from_observed_material(
                &req,
                12,
                sha256_hex(b"model bytes"),
                sha256_hex(b"version"),
                sha256_hex(b"help"),
                true,
                true,
                true,
            )
            .unwrap_err(),
            GemmaOwnerApprovedLocalArtifactReceiptMaterializerError::UnsupportedModel(_)
        ));
    }
}
