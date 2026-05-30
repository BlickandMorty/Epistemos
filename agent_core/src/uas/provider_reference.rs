//! Replayable reference manifests for 70B/provider comparisons.
//!
//! This is the safe half of the next 70B gate: record what reference
//! evidence exists and whether it is replayable before any live model run,
//! provider call, or prompt-level KL probe is attempted.

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::path::Path;

const ROW_ROOT: &str = "artifacts/falsifiers/70b_local_cocktail_lite/";
const KV_PROMPT_SUITE_ROOT: &str = "artifacts/falsifiers/kv_direct_gate/";
const MIN_PROMPT_LEVEL_PROMPTS: u32 = 50;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProviderReferenceKind {
    LocalFp16Replay,
    HostedZeroRetentionReceipt,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReferenceEvidenceScope {
    PromptLevelComparison,
    ShapeOnlyFixture,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReferenceDataSentClass {
    LocalOnly,
    PublicBenchmarkIds,
    HashedPromptIds,
    RedactedFeatureDigest,
    PromptEmbeddings,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReferenceRetentionClaim {
    LocalFileOnly,
    ZeroRetention,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProviderReferenceManifest {
    pub schema_version: String,
    pub model_id: String,
    pub reference_kind: ProviderReferenceKind,
    pub evidence_scope: ReferenceEvidenceScope,
    pub artifact_ref: String,
    pub artifact_sha256: String,
    pub prompt_suite_id: String,
    pub prompt_suite_artifact_ref: String,
    pub prompt_suite_artifact_sha256: String,
    pub request_id_hash: Option<String>,
    pub redaction_digest: Option<String>,
    pub data_sent_class: ReferenceDataSentClass,
    pub retention_claim: ReferenceRetentionClaim,
    pub replay_allowed: bool,
    pub prompt_count: u32,
    pub notes: String,
}

impl ProviderReferenceManifest {
    pub const SCHEMA_VERSION: &'static str = "provider_reference_manifest.v1";

    pub fn from_json_str(input: &str) -> Result<Self, ProviderReferenceManifestError> {
        let manifest: Self =
            serde_json::from_str(input).map_err(|_| ProviderReferenceManifestError::InvalidJson)?;
        manifest.validate()?;
        Ok(manifest)
    }

    pub fn from_path(path: impl AsRef<Path>) -> Result<Self, ProviderReferenceManifestError> {
        let input =
            std::fs::read_to_string(path).map_err(|_| ProviderReferenceManifestError::Io)?;
        Self::from_json_str(&input)
    }

    pub fn validate_replay_files_at(
        &self,
        base_dir: impl AsRef<Path>,
    ) -> Result<(), ProviderReferenceManifestError> {
        self.validate()?;
        let base_dir = base_dir.as_ref();
        validate_file_digest(base_dir, &self.artifact_ref, &self.artifact_sha256).map_err(
            |error| match error {
                ReplayFileError::Missing => ProviderReferenceManifestError::ArtifactFileMissing,
                ReplayFileError::DigestMismatch => {
                    ProviderReferenceManifestError::ArtifactDigestMismatch
                }
            },
        )?;
        validate_file_digest(
            base_dir,
            &self.prompt_suite_artifact_ref,
            &self.prompt_suite_artifact_sha256,
        )
        .map_err(|error| match error {
            ReplayFileError::Missing => ProviderReferenceManifestError::PromptSuiteFileMissing,
            ReplayFileError::DigestMismatch => {
                ProviderReferenceManifestError::PromptSuiteDigestMismatch
            }
        })?;
        Ok(())
    }

    pub fn validate(&self) -> Result<(), ProviderReferenceManifestError> {
        if self.schema_version != Self::SCHEMA_VERSION {
            return Err(ProviderReferenceManifestError::BadSchemaVersion);
        }
        if self.model_id.trim().is_empty() {
            return Err(ProviderReferenceManifestError::MissingModelId);
        }
        if !self.replay_allowed {
            return Err(ProviderReferenceManifestError::ReplayNotAllowed);
        }
        if self.prompt_count == 0 {
            return Err(ProviderReferenceManifestError::EmptyPromptSet);
        }
        if self.evidence_scope == ReferenceEvidenceScope::PromptLevelComparison
            && self.prompt_count < MIN_PROMPT_LEVEL_PROMPTS
        {
            return Err(ProviderReferenceManifestError::InsufficientPromptLevelPrompts);
        }
        if self.prompt_suite_id.trim().is_empty() {
            return Err(ProviderReferenceManifestError::MissingPromptSuiteId);
        }
        validate_row_root_path(&self.artifact_ref)?;
        validate_sha256(&self.artifact_sha256)?;
        validate_prompt_suite_path(&self.prompt_suite_artifact_ref)?;
        validate_sha256(&self.prompt_suite_artifact_sha256)?;
        if let Some(hash) = &self.request_id_hash {
            validate_sha256(hash)?;
        }
        if let Some(digest) = &self.redaction_digest {
            validate_sha256(digest)?;
        }
        match self.reference_kind {
            ProviderReferenceKind::LocalFp16Replay => {
                if self.data_sent_class != ReferenceDataSentClass::LocalOnly {
                    return Err(ProviderReferenceManifestError::LocalReferenceSentData);
                }
                if self.retention_claim != ReferenceRetentionClaim::LocalFileOnly {
                    return Err(ProviderReferenceManifestError::BadRetentionClaim);
                }
            }
            ProviderReferenceKind::HostedZeroRetentionReceipt => {
                if self.data_sent_class == ReferenceDataSentClass::LocalOnly {
                    return Err(ProviderReferenceManifestError::HostedReferenceMissingDataClass);
                }
                if self.retention_claim != ReferenceRetentionClaim::ZeroRetention {
                    return Err(ProviderReferenceManifestError::BadRetentionClaim);
                }
                if self.request_id_hash.is_none() || self.redaction_digest.is_none() {
                    return Err(ProviderReferenceManifestError::MissingHostedReceiptDigest);
                }
            }
        }
        Ok(())
    }

    pub fn is_prompt_level_reference(&self) -> bool {
        self.evidence_scope == ReferenceEvidenceScope::PromptLevelComparison
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ProviderReferenceManifestError {
    InvalidJson,
    Io,
    BadSchemaVersion,
    MissingModelId,
    ReplayNotAllowed,
    EmptyPromptSet,
    InsufficientPromptLevelPrompts,
    MissingPromptSuiteId,
    ArtifactOutsideRowRoot,
    PromptSuiteOutsideAllowedRoots,
    ArtifactContainsDotSegment,
    InvalidSha256,
    LocalReferenceSentData,
    HostedReferenceMissingDataClass,
    BadRetentionClaim,
    MissingHostedReceiptDigest,
    ArtifactFileMissing,
    PromptSuiteFileMissing,
    ArtifactDigestMismatch,
    PromptSuiteDigestMismatch,
}

impl std::fmt::Display for ProviderReferenceManifestError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidJson => write!(f, "provider reference manifest is invalid JSON"),
            Self::Io => write!(f, "provider reference manifest could not be read"),
            Self::BadSchemaVersion => write!(f, "provider reference schema version mismatch"),
            Self::MissingModelId => write!(f, "provider reference model_id is required"),
            Self::ReplayNotAllowed => write!(f, "provider reference must be replayable"),
            Self::EmptyPromptSet => write!(f, "provider reference prompt_count must be nonzero"),
            Self::InsufficientPromptLevelPrompts => {
                write!(
                    f,
                    "prompt-level provider reference requires at least 50 prompts"
                )
            }
            Self::MissingPromptSuiteId => {
                write!(f, "provider reference prompt_suite_id is required")
            }
            Self::ArtifactOutsideRowRoot => {
                write!(f, "provider reference artifact is outside the 70B row root")
            }
            Self::PromptSuiteOutsideAllowedRoots => write!(
                f,
                "provider reference prompt suite is outside allowed artifact roots"
            ),
            Self::ArtifactContainsDotSegment => {
                write!(f, "provider reference artifact path contains a dot segment")
            }
            Self::InvalidSha256 => write!(
                f,
                "provider reference digest must be sha256:<64 lowercase hex>"
            ),
            Self::LocalReferenceSentData => write!(
                f,
                "local fp16 reference must not claim hosted data was sent"
            ),
            Self::HostedReferenceMissingDataClass => {
                write!(f, "hosted reference must name a non-local data-sent class")
            }
            Self::BadRetentionClaim => write!(
                f,
                "provider reference retention claim does not match its kind"
            ),
            Self::MissingHostedReceiptDigest => {
                write!(f, "hosted reference requires request and redaction digests")
            }
            Self::ArtifactFileMissing => {
                write!(f, "provider reference artifact file is missing")
            }
            Self::PromptSuiteFileMissing => {
                write!(f, "provider reference prompt-suite file is missing")
            }
            Self::ArtifactDigestMismatch => {
                write!(f, "provider reference artifact digest mismatch")
            }
            Self::PromptSuiteDigestMismatch => {
                write!(f, "provider reference prompt-suite digest mismatch")
            }
        }
    }
}

impl std::error::Error for ProviderReferenceManifestError {}

fn validate_row_root_path(path: &str) -> Result<(), ProviderReferenceManifestError> {
    if has_dot_segment(path) {
        return Err(ProviderReferenceManifestError::ArtifactContainsDotSegment);
    }
    if !path.starts_with(ROW_ROOT) {
        return Err(ProviderReferenceManifestError::ArtifactOutsideRowRoot);
    }
    Ok(())
}

fn validate_prompt_suite_path(path: &str) -> Result<(), ProviderReferenceManifestError> {
    if has_dot_segment(path) {
        return Err(ProviderReferenceManifestError::ArtifactContainsDotSegment);
    }
    if path.starts_with(ROW_ROOT) || path.starts_with(KV_PROMPT_SUITE_ROOT) {
        return Ok(());
    }
    Err(ProviderReferenceManifestError::PromptSuiteOutsideAllowedRoots)
}

fn has_dot_segment(path: &str) -> bool {
    path.split('/').any(|part| part == "." || part == "..")
}

fn validate_sha256(value: &str) -> Result<(), ProviderReferenceManifestError> {
    let Some(hex) = value.strip_prefix("sha256:") else {
        return Err(ProviderReferenceManifestError::InvalidSha256);
    };
    if hex.len() == 64
        && hex
            .chars()
            .all(|ch| ch.is_ascii_hexdigit() && !ch.is_ascii_uppercase())
    {
        Ok(())
    } else {
        Err(ProviderReferenceManifestError::InvalidSha256)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum ReplayFileError {
    Missing,
    DigestMismatch,
}

fn validate_file_digest(
    base_dir: &Path,
    artifact_ref: &str,
    expected_sha256: &str,
) -> Result<(), ReplayFileError> {
    let path = base_dir.join(artifact_ref);
    let bytes = std::fs::read(path).map_err(|_| ReplayFileError::Missing)?;
    let actual = format!("sha256:{}", hex_lower(&Sha256::digest(&bytes)));
    if actual == expected_sha256 {
        Ok(())
    } else {
        Err(ReplayFileError::DigestMismatch)
    }
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

    fn sha(byte: char) -> String {
        format!("sha256:{}", byte.to_string().repeat(64))
    }

    fn local_manifest() -> ProviderReferenceManifest {
        ProviderReferenceManifest {
            schema_version: ProviderReferenceManifest::SCHEMA_VERSION.to_string(),
            model_id: "qwen3-70b-fp16-reference".to_string(),
            reference_kind: ProviderReferenceKind::LocalFp16Replay,
            evidence_scope: ReferenceEvidenceScope::PromptLevelComparison,
            artifact_ref: "artifacts/falsifiers/70b_local_cocktail_lite/local_reference.jsonl"
                .to_string(),
            artifact_sha256: sha('a'),
            prompt_suite_id: "qwen3_8b_128k_kv_direct_prompt_suite_v1".to_string(),
            prompt_suite_artifact_ref: "artifacts/falsifiers/kv_direct_gate/prompt_suite.json"
                .to_string(),
            prompt_suite_artifact_sha256: sha('d'),
            request_id_hash: None,
            redaction_digest: None,
            data_sent_class: ReferenceDataSentClass::LocalOnly,
            retention_claim: ReferenceRetentionClaim::LocalFileOnly,
            replay_allowed: true,
            prompt_count: 50,
            notes: "local replay digest only".to_string(),
        }
    }

    #[test]
    fn local_fp16_reference_is_replayable_without_provider_data() {
        let manifest = local_manifest();
        assert!(manifest.validate().is_ok());
        assert_eq!(
            manifest.prompt_suite_artifact_ref,
            "artifacts/falsifiers/kv_direct_gate/prompt_suite.json"
        );
        let encoded = serde_json::to_string(&manifest).unwrap();
        assert_eq!(
            ProviderReferenceManifest::from_json_str(&encoded).unwrap(),
            manifest
        );
        assert!(manifest.is_prompt_level_reference());
    }

    #[test]
    fn shape_only_fixture_validates_but_is_not_prompt_level_evidence() {
        let mut manifest = local_manifest();
        manifest.evidence_scope = ReferenceEvidenceScope::ShapeOnlyFixture;
        manifest.prompt_count = 1;
        assert!(manifest.validate().is_ok());
        assert!(!manifest.is_prompt_level_reference());
    }

    #[test]
    fn prompt_level_reference_requires_enough_prompts_and_suite_digest() {
        let mut manifest = local_manifest();
        manifest.prompt_count = 49;
        assert_eq!(
            manifest.validate(),
            Err(ProviderReferenceManifestError::InsufficientPromptLevelPrompts)
        );
        manifest.prompt_count = 50;
        manifest.prompt_suite_artifact_ref =
            "artifacts/falsifiers/shared/prompt_suite.json".to_string();
        assert_eq!(
            manifest.validate(),
            Err(ProviderReferenceManifestError::PromptSuiteOutsideAllowedRoots)
        );
        manifest.prompt_suite_artifact_ref =
            "artifacts/falsifiers/kv_direct_gate/prompt_suite.json".to_string();
        manifest.prompt_suite_artifact_sha256 = "sha256:ABC".to_string();
        assert_eq!(
            manifest.validate(),
            Err(ProviderReferenceManifestError::InvalidSha256)
        );
    }

    #[test]
    fn rejects_path_traversal_and_outside_row_root() {
        let mut manifest = local_manifest();
        manifest.artifact_ref =
            "artifacts/falsifiers/70b_local_cocktail_lite/../shared/ref.json".to_string();
        assert_eq!(
            manifest.validate(),
            Err(ProviderReferenceManifestError::ArtifactContainsDotSegment)
        );
        manifest.artifact_ref = "artifacts/falsifiers/shared/ref.json".to_string();
        assert_eq!(
            manifest.validate(),
            Err(ProviderReferenceManifestError::ArtifactOutsideRowRoot)
        );
    }

    #[test]
    fn hosted_reference_requires_zero_retention_and_digests() {
        let mut manifest = local_manifest();
        manifest.reference_kind = ProviderReferenceKind::HostedZeroRetentionReceipt;
        manifest.data_sent_class = ReferenceDataSentClass::HashedPromptIds;
        manifest.retention_claim = ReferenceRetentionClaim::ZeroRetention;
        assert_eq!(
            manifest.validate(),
            Err(ProviderReferenceManifestError::MissingHostedReceiptDigest)
        );
        manifest.request_id_hash = Some(sha('b'));
        manifest.redaction_digest = Some(sha('c'));
        assert!(manifest.validate().is_ok());
    }

    #[test]
    fn local_reference_rejects_nonlocal_data_class() {
        let mut manifest = local_manifest();
        manifest.data_sent_class = ReferenceDataSentClass::HashedPromptIds;
        assert_eq!(
            manifest.validate(),
            Err(ProviderReferenceManifestError::LocalReferenceSentData)
        );
    }

    #[test]
    fn replay_file_validation_requires_existing_digest_matched_files() {
        let temp = tempfile::tempdir().unwrap();
        let mut manifest = local_manifest();
        manifest.artifact_ref =
            "artifacts/falsifiers/70b_local_cocktail_lite/local_reference.jsonl".to_string();
        manifest.prompt_suite_artifact_ref =
            "artifacts/falsifiers/kv_direct_gate/prompt_suite.json".to_string();
        let reference_path = temp.path().join(&manifest.artifact_ref);
        let suite_path = temp.path().join(&manifest.prompt_suite_artifact_ref);
        std::fs::create_dir_all(reference_path.parent().unwrap()).unwrap();
        std::fs::create_dir_all(suite_path.parent().unwrap()).unwrap();
        let reference_bytes = b"{\"logits_digest\":\"reference\"}\n";
        let suite_bytes = b"{\"suite\":\"prompt-suite\"}\n";
        std::fs::write(&reference_path, reference_bytes).unwrap();
        std::fs::write(&suite_path, suite_bytes).unwrap();
        manifest.artifact_sha256 = crate::falsifier_artifacts::sha256_hex(reference_bytes);
        manifest.prompt_suite_artifact_sha256 = crate::falsifier_artifacts::sha256_hex(suite_bytes);

        assert!(manifest.validate_replay_files_at(temp.path()).is_ok());

        std::fs::write(&reference_path, b"tampered\n").unwrap();
        assert_eq!(
            manifest.validate_replay_files_at(temp.path()),
            Err(ProviderReferenceManifestError::ArtifactDigestMismatch)
        );
    }

    #[test]
    fn replay_file_validation_rejects_missing_prompt_suite_file() {
        let temp = tempfile::tempdir().unwrap();
        let mut manifest = local_manifest();
        manifest.artifact_ref =
            "artifacts/falsifiers/70b_local_cocktail_lite/local_reference.jsonl".to_string();
        manifest.prompt_suite_artifact_ref =
            "artifacts/falsifiers/kv_direct_gate/prompt_suite.json".to_string();
        let reference_path = temp.path().join(&manifest.artifact_ref);
        std::fs::create_dir_all(reference_path.parent().unwrap()).unwrap();
        let reference_bytes = b"{\"logits_digest\":\"reference\"}\n";
        std::fs::write(&reference_path, reference_bytes).unwrap();
        manifest.artifact_sha256 = crate::falsifier_artifacts::sha256_hex(reference_bytes);
        manifest.prompt_suite_artifact_sha256 = crate::falsifier_artifacts::sha256_hex(b"missing");

        assert_eq!(
            manifest.validate_replay_files_at(temp.path()),
            Err(ProviderReferenceManifestError::PromptSuiteFileMissing)
        );
    }
}
