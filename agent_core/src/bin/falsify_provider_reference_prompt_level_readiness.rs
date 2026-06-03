//! `falsify_provider_reference_prompt_level_readiness` — prompt-level
//! reference readiness gate.
//!
//! The shape-only manifest proves the ABI. This harness audits the real
//! prompt-level path named by `EPISTEMOS_70B_PROVIDER_REFERENCE` and keeps the
//! 70B comparison gate red until the manifest is prompt-level, replayable, and
//! digest-bound.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{ProviderReferenceManifest, ReferenceEvidenceScope};

const FALSIFIER_ID: &str = "F-ProviderReferencePromptLevel-Readiness";
const FIXTURE_ID: &str = "provider_reference_prompt_level_readiness_v1";
const COMMAND: &str = "Tools/falsifiers/f_provider_reference_prompt_level_readiness.sh";
const OUTPUT: &str = "artifacts/falsifiers/provider_reference_prompt_level_readiness/result.json";
const PROVIDER_REFERENCE_ENV: &str = "EPISTEMOS_70B_PROVIDER_REFERENCE";
const MIN_PROMPT_LEVEL_PROMPTS: u32 = 50;

fn main() -> std::process::ExitCode {
    let provider_reference_path = std::env::var(PROVIDER_REFERENCE_ENV).ok();
    let report = build_report(provider_reference_path.as_deref(), Path::new("."));
    let path = PathBuf::from(OUTPUT);
    if let Some(parent) = path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create provider reference readiness directory: {error}");
            return std::process::ExitCode::from(2);
        }
    }
    let mut file = match std::fs::File::create(&path) {
        Ok(file) => file,
        Err(error) => {
            eprintln!("failed to open provider reference readiness artifact: {error}");
            return std::process::ExitCode::from(2);
        }
    };
    if let Err(error) = write_artifact(&mut file, &report.artifact) {
        eprintln!("failed to write provider reference readiness artifact: {error}");
        return std::process::ExitCode::from(2);
    }
    println!(
        "{FALSIFIER_ID}: overall_pass={} primary_blocker={} artifact={}",
        report.artifact.overall_pass, report.primary_blocker, OUTPUT
    );
    if report.artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

// UAS: uas/falsifier/provider-reference-prompt-level-readiness/report
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::VerifiedFloor
struct ReadinessReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    primary_blocker: String,
}

fn build_report(path: Option<&str>, base_dir: &Path) -> ReadinessReport {
    let status = ProviderPromptLevelStatus::from_path(path, base_dir);
    let primary_blocker = status.primary_blocker();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_reference_env_set",
        path.is_some(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "manifest_file_exists",
        status.manifest_file_exists,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "manifest_valid",
        status.manifest_valid,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_level_scope",
        status.prompt_level_scope,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_count_floor",
        status.prompt_count_floor,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "replay_files_valid",
        status.replay_files_valid,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_level_reference_available",
        status.prompt_level_reference_available,
    );
    add_label(&mut measurements, "primary_blocker", &primary_blocker);
    add_label(
        &mut measurements,
        "provider_reference_candidate_path",
        path.unwrap_or("EPISTEMOS_70B_PROVIDER_REFERENCE=unset"),
    );
    add_label(
        &mut measurements,
        "provider_reference_status",
        &status.status_label,
    );
    add_label(
        &mut measurements,
        "manifest_error",
        status.manifest_error.as_deref().unwrap_or("none"),
    );
    add_label(
        &mut measurements,
        "replay_error",
        status.replay_error.as_deref().unwrap_or("none"),
    );
    add_label(
        &mut measurements,
        "reference_kind",
        status.reference_kind.as_deref().unwrap_or("unknown"),
    );
    add_label(
        &mut measurements,
        "evidence_scope",
        status.evidence_scope.as_deref().unwrap_or("unknown"),
    );
    add_label(
        &mut measurements,
        "artifact_ref",
        status.artifact_ref.as_deref().unwrap_or("unknown"),
    );
    add_label(
        &mut measurements,
        "prompt_suite_artifact_ref",
        status
            .prompt_suite_artifact_ref
            .as_deref()
            .unwrap_or("unknown"),
    );
    measurements.insert(
        "prompt_count".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(status.prompt_count)),
            unit: "prompts".to_string(),
        },
    );
    thresholds.insert(
        "prompt_count".to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(MIN_PROMPT_LEVEL_PROMPTS)),
            unit: "prompts".to_string(),
        },
    );

    let anomalies = if status.prompt_level_reference_available {
        Vec::new()
    } else {
        vec![serde_json::json!({
            "kind": "prompt_level_reference_not_ready",
            "detail": format!(
                "primary_blocker={primary_blocker}; {PROVIDER_REFERENCE_ENV} must point to a prompt-level ProviderReferenceManifest with digest-valid retained replay files before F-70B-Local-Cocktail-Lite can advance."
            )
        })]
    };

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: if status.prompt_level_reference_available {
            ArtifactKind::PrimaryWitness
        } else {
            ArtifactKind::FailureReport
        },
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: if status.prompt_level_reference_available {
            FallbackTier::Primary
        } else {
            FallbackTier::Fail
        },
        anomalies,
        notes: format!(
            "prompt_level_provider_reference_readiness; primary_blocker={primary_blocker}; shape-only fixtures do not satisfy this gate"
        ),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    ReadinessReport {
        artifact,
        primary_blocker,
    }
}

// UAS: uas/falsifier/provider-reference-prompt-level-readiness/status
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::VerifiedFloor
struct ProviderPromptLevelStatus {
    manifest_file_exists: bool,
    manifest_valid: bool,
    prompt_level_scope: bool,
    prompt_count_floor: bool,
    replay_files_valid: bool,
    prompt_level_reference_available: bool,
    prompt_count: u32,
    status_label: String,
    manifest_error: Option<String>,
    replay_error: Option<String>,
    reference_kind: Option<String>,
    evidence_scope: Option<String>,
    artifact_ref: Option<String>,
    prompt_suite_artifact_ref: Option<String>,
}

impl ProviderPromptLevelStatus {
    fn from_path(path: Option<&str>, base_dir: &Path) -> Self {
        let Some(path) = path else {
            return Self::missing("env_unset", "missing_provider_reference_env");
        };
        let path = Path::new(path);
        if !path.exists() {
            return Self::missing("path_missing", "provider_reference_manifest_path_missing");
        }
        match ProviderReferenceManifest::from_path(path) {
            Ok(manifest) => {
                let replay_result = manifest.validate_replay_files_at(base_dir);
                let replay_files_valid = replay_result.is_ok();
                let prompt_level_scope =
                    manifest.evidence_scope == ReferenceEvidenceScope::PromptLevelComparison;
                let prompt_count_floor = manifest.prompt_count >= MIN_PROMPT_LEVEL_PROMPTS;
                let prompt_level_reference_available =
                    prompt_level_scope && prompt_count_floor && replay_files_valid;
                let status_label = if prompt_level_reference_available {
                    "prompt_level_replayable_manifest"
                } else if !prompt_level_scope {
                    "shape_only_manifest"
                } else if !replay_files_valid {
                    "prompt_level_replay_files_invalid"
                } else {
                    "prompt_level_manifest_not_ready"
                }
                .to_string();
                Self {
                    manifest_file_exists: true,
                    manifest_valid: true,
                    prompt_level_scope,
                    prompt_count_floor,
                    replay_files_valid,
                    prompt_level_reference_available,
                    prompt_count: manifest.prompt_count,
                    status_label,
                    manifest_error: None,
                    replay_error: replay_result.err().map(|error| error.to_string()),
                    reference_kind: Some(format!("{:?}", manifest.reference_kind)),
                    evidence_scope: Some(format!("{:?}", manifest.evidence_scope)),
                    artifact_ref: Some(manifest.artifact_ref),
                    prompt_suite_artifact_ref: Some(manifest.prompt_suite_artifact_ref),
                }
            }
            Err(error) => Self {
                manifest_file_exists: true,
                manifest_valid: false,
                prompt_level_scope: false,
                prompt_count_floor: false,
                replay_files_valid: false,
                prompt_level_reference_available: false,
                prompt_count: 0,
                status_label: "invalid_manifest".to_string(),
                manifest_error: Some(error.to_string()),
                replay_error: None,
                reference_kind: None,
                evidence_scope: None,
                artifact_ref: None,
                prompt_suite_artifact_ref: None,
            },
        }
    }

    fn missing(status_label: &str, manifest_error: &str) -> Self {
        Self {
            manifest_file_exists: false,
            manifest_valid: false,
            prompt_level_scope: false,
            prompt_count_floor: false,
            replay_files_valid: false,
            prompt_level_reference_available: false,
            prompt_count: 0,
            status_label: status_label.to_string(),
            manifest_error: Some(manifest_error.to_string()),
            replay_error: None,
            reference_kind: None,
            evidence_scope: None,
            artifact_ref: None,
            prompt_suite_artifact_ref: None,
        }
    }

    fn primary_blocker(&self) -> String {
        if self.prompt_level_reference_available {
            "ready_for_70b_prompt_level_comparison".to_string()
        } else if !self.manifest_file_exists {
            self.manifest_error
                .clone()
                .unwrap_or_else(|| "provider_reference_manifest_missing".to_string())
        } else if !self.manifest_valid {
            "provider_reference_manifest_invalid".to_string()
        } else if !self.prompt_level_scope {
            "provider_reference_shape_only_not_prompt_level".to_string()
        } else if !self.prompt_count_floor {
            "provider_reference_prompt_count_below_floor".to_string()
        } else if !self.replay_files_valid {
            "provider_reference_replay_files_invalid".to_string()
        } else {
            "provider_reference_not_ready".to_string()
        }
    }
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: bool,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Bool(value),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value);
}

fn add_label(measurements: &mut BTreeMap<String, Measurement>, axis: &str, value: &str) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "label".to_string(),
        },
    );
}

#[cfg(test)]
mod tests {
    use super::*;
    use agent_core::falsifier_artifacts::sha256_hex;
    use agent_core::uas::{ProviderReferenceKind, ReferenceDataSentClass, ReferenceRetentionClaim};

    fn write_manifest(
        root: &Path,
        scope: ReferenceEvidenceScope,
        prompt_count: u32,
        write_prompt_suite: bool,
    ) -> String {
        let artifact_ref =
            "artifacts/falsifiers/70b_local_cocktail_lite/test_prompt_reference.jsonl".to_string();
        let prompt_suite_artifact_ref =
            "artifacts/falsifiers/70b_local_cocktail_lite/test_prompt_suite.json".to_string();
        let artifact_path = root.join(&artifact_ref);
        let prompt_suite_path = root.join(&prompt_suite_artifact_ref);
        std::fs::create_dir_all(artifact_path.parent().unwrap()).unwrap();
        std::fs::create_dir_all(prompt_suite_path.parent().unwrap()).unwrap();
        let reference_bytes = b"{\"prompt_id\":\"p0\",\"logits_digest\":\"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}\n";
        let prompt_suite_bytes = b"{\"suite\":\"prompt-level\"}\n";
        std::fs::write(&artifact_path, reference_bytes).unwrap();
        if write_prompt_suite {
            std::fs::write(&prompt_suite_path, prompt_suite_bytes).unwrap();
        }
        let manifest = ProviderReferenceManifest {
            schema_version: ProviderReferenceManifest::SCHEMA_VERSION.to_string(),
            model_id: "test-70b-reference".to_string(),
            reference_kind: ProviderReferenceKind::LocalFp16Replay,
            evidence_scope: scope,
            artifact_ref,
            artifact_sha256: sha256_hex(reference_bytes),
            prompt_suite_id: "test_prompt_level_suite".to_string(),
            prompt_suite_artifact_ref,
            prompt_suite_artifact_sha256: sha256_hex(prompt_suite_bytes),
            request_id_hash: None,
            redaction_digest: None,
            data_sent_class: ReferenceDataSentClass::LocalOnly,
            retention_claim: ReferenceRetentionClaim::LocalFileOnly,
            replay_allowed: true,
            prompt_count,
            notes: "test prompt-level readiness fixture".to_string(),
        };
        let manifest_path = root.join("provider_reference.json");
        std::fs::write(
            &manifest_path,
            serde_json::to_vec_pretty(&manifest).unwrap(),
        )
        .unwrap();
        manifest_path.display().to_string()
    }

    #[test]
    fn env_unset_keeps_prompt_level_reference_red() {
        let temp = tempfile::tempdir().unwrap();
        let report = build_report(None, temp.path());

        assert!(!report.artifact.overall_pass);
        assert_eq!(report.primary_blocker, "missing_provider_reference_env");
        assert_eq!(
            report
                .artifact
                .pass_per_axis
                .get("prompt_level_reference_available"),
            Some(&false)
        );
    }

    #[test]
    fn shape_only_manifest_does_not_satisfy_prompt_level_readiness() {
        let temp = tempfile::tempdir().unwrap();
        let manifest_path = write_manifest(
            temp.path(),
            ReferenceEvidenceScope::ShapeOnlyFixture,
            1,
            true,
        );
        let report = build_report(Some(&manifest_path), temp.path());

        assert!(!report.artifact.overall_pass);
        assert_eq!(
            report.primary_blocker,
            "provider_reference_shape_only_not_prompt_level"
        );
        assert_eq!(
            report.artifact.pass_per_axis.get("manifest_valid"),
            Some(&true)
        );
        assert_eq!(
            report.artifact.pass_per_axis.get("replay_files_valid"),
            Some(&true)
        );
        assert_eq!(
            report.artifact.pass_per_axis.get("prompt_level_scope"),
            Some(&false)
        );
    }

    #[test]
    fn prompt_level_manifest_requires_retained_replay_files() {
        let temp = tempfile::tempdir().unwrap();
        let manifest_path = write_manifest(
            temp.path(),
            ReferenceEvidenceScope::PromptLevelComparison,
            50,
            false,
        );
        let report = build_report(Some(&manifest_path), temp.path());

        assert!(!report.artifact.overall_pass);
        assert_eq!(
            report.primary_blocker,
            "provider_reference_replay_files_invalid"
        );
        assert_eq!(
            report.artifact.pass_per_axis.get("prompt_level_scope"),
            Some(&true)
        );
        assert_eq!(
            report.artifact.pass_per_axis.get("replay_files_valid"),
            Some(&false)
        );
    }

    #[test]
    fn prompt_level_manifest_with_replay_files_can_pass_readiness() {
        let temp = tempfile::tempdir().unwrap();
        let manifest_path = write_manifest(
            temp.path(),
            ReferenceEvidenceScope::PromptLevelComparison,
            50,
            true,
        );
        let report = build_report(Some(&manifest_path), temp.path());

        assert!(report.artifact.overall_pass);
        assert_eq!(
            report.primary_blocker,
            "ready_for_70b_prompt_level_comparison"
        );
        assert_eq!(
            report
                .artifact
                .pass_per_axis
                .get("prompt_level_reference_available"),
            Some(&true)
        );
    }
}
