//! `falsify_provider_reference_manifest_dry_run` — shape-only reference gate.
//!
//! This writes a tiny retained local-reference manifest under the 70B row
//! root and proves the manifest validator accepts it as shape evidence while
//! refusing to count it as prompt-level fp16/provider evidence.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, sha256_hex, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProviderReferenceKind, ProviderReferenceManifest, ReferenceDataSentClass,
    ReferenceEvidenceScope, ReferenceRetentionClaim,
};

const FALSIFIER_ID: &str = "F-ProviderReferenceManifest-DryRun";
const FIXTURE_ID: &str = "provider_reference_manifest_shape_only_v1";
const COMMAND: &str = "Tools/falsifiers/f_provider_reference_manifest_dry_run.sh";
const ROW_ROOT: &str =
    "artifacts/falsifiers/70b_local_cocktail_lite/provider_reference_manifest_dry_run";
const SIDE_CAR: &str =
    "artifacts/falsifiers/70b_local_cocktail_lite/provider_reference_manifest_dry_run/shape_only_reference.jsonl";
const PROMPT_SUITE: &str =
    "artifacts/falsifiers/70b_local_cocktail_lite/provider_reference_manifest_dry_run/shape_only_prompt_suite.json";
const MANIFEST: &str =
    "artifacts/falsifiers/70b_local_cocktail_lite/provider_reference_manifest_dry_run/shape_only_manifest.json";
const RESULT: &str = "artifacts/falsifiers/provider_reference_manifest_dry_run/result.json";

fn main() -> std::process::ExitCode {
    let report = match build_report() {
        Ok(report) => report,
        Err(error) => {
            eprintln!("failed to build {FALSIFIER_ID}: {error}");
            return std::process::ExitCode::from(2);
        }
    };
    let path = PathBuf::from(RESULT);
    if let Some(parent) = path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create artifact directory: {error}");
            return std::process::ExitCode::from(2);
        }
    }
    let mut file = match std::fs::File::create(&path) {
        Ok(file) => file,
        Err(error) => {
            eprintln!("failed to open artifact: {error}");
            return std::process::ExitCode::from(2);
        }
    };
    if let Err(error) = write_artifact(&mut file, &report) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }
    println!(
        "{FALSIFIER_ID}: overall_pass={} manifest={} artifact={}",
        report.overall_pass, MANIFEST, RESULT
    );
    if report.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_report(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    std::fs::create_dir_all(ROW_ROOT)?;
    let sidecar_bytes = b"{\"scope\":\"shape_only_fixture\",\"prompt_count\":1,\"not_prompt_level_reference\":true}\n";
    std::fs::write(SIDE_CAR, sidecar_bytes)?;
    let sidecar_digest = sha256_hex(sidecar_bytes);
    let prompt_suite_bytes = b"{\"suite_id\":\"shape_only_provider_reference_prompt_suite_v1\",\"prompt_count\":1,\"prompt_ids\":[\"sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\"],\"raw_prompt_text_retained\":false}\n";
    std::fs::write(PROMPT_SUITE, prompt_suite_bytes)?;
    let prompt_suite_digest = sha256_hex(prompt_suite_bytes);
    let manifest = ProviderReferenceManifest {
        schema_version: ProviderReferenceManifest::SCHEMA_VERSION.to_string(),
        model_id: "shape-only-70b-reference-fixture".to_string(),
        reference_kind: ProviderReferenceKind::LocalFp16Replay,
        evidence_scope: ReferenceEvidenceScope::ShapeOnlyFixture,
        artifact_ref: SIDE_CAR.to_string(),
        artifact_sha256: sidecar_digest.clone(),
        prompt_suite_id: "shape_only_provider_reference_prompt_suite_v1".to_string(),
        prompt_suite_artifact_ref: PROMPT_SUITE.to_string(),
        prompt_suite_artifact_sha256: prompt_suite_digest.clone(),
        request_id_hash: None,
        redaction_digest: None,
        data_sent_class: ReferenceDataSentClass::LocalOnly,
        retention_claim: ReferenceRetentionClaim::LocalFileOnly,
        replay_allowed: true,
        prompt_count: 1,
        notes: "shape-only retained fixture; not fp16/provider evidence".to_string(),
    };
    manifest.validate()?;
    let manifest_bytes = serde_json::to_vec_pretty(&manifest)?;
    std::fs::write(MANIFEST, &manifest_bytes)?;
    let reloaded = ProviderReferenceManifest::from_path(MANIFEST)?;
    let replay_files_valid = reloaded.validate_replay_files_at(".").is_ok();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "shape_fixture_written",
        PathBuf::from(SIDE_CAR).exists() && PathBuf::from(MANIFEST).exists(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "manifest_valid",
        reloaded.validate().is_ok(),
    );
    add_bool_axis_expected(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_level_reference",
        reloaded.is_prompt_level_reference(),
        false,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "does_not_advance_70b_reference_gate",
        !reloaded.is_prompt_level_reference(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "row_root_path",
        reloaded
            .artifact_ref
            .starts_with("artifacts/falsifiers/70b_local_cocktail_lite/"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "digest_matches_sidecar",
        reloaded.artifact_sha256 == sidecar_digest,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "replay_files_valid",
        replay_files_valid,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_suite_bound",
        reloaded.prompt_suite_id == "shape_only_provider_reference_prompt_suite_v1"
            && reloaded.prompt_suite_artifact_ref == PROMPT_SUITE
            && reloaded.prompt_suite_artifact_sha256 == prompt_suite_digest,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_provider_call",
        reloaded.request_id_hash.is_none() && reloaded.redaction_digest.is_none(),
    );

    measurements.insert(
        "manifest_path".to_string(),
        Measurement {
            value: serde_json::Value::String(MANIFEST.to_string()),
            unit: "path".to_string(),
        },
    );
    measurements.insert(
        "sidecar_sha256".to_string(),
        Measurement {
            value: serde_json::Value::String(sidecar_digest),
            unit: "sha256".to_string(),
        },
    );
    measurements.insert(
        "prompt_suite_sha256".to_string(),
        Measurement {
            value: serde_json::Value::String(prompt_suite_digest),
            unit: "sha256".to_string(),
        },
    );

    Ok(ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: vec![serde_json::json!({
            "kind": "scope_guard",
            "detail": "shape-only provider-reference fixture; no provider call, no prompts sent, no fp16 logits, prompt suite is digest-bound, no 70B runtime gate advancement"
        })],
        notes: "Validates provider-reference manifest shape only; does not count as prompt-level fp16/provider reference.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: bool,
) {
    add_bool_axis_expected(measurements, thresholds, pass_per_axis, axis, value, true);
}

fn add_bool_axis_expected(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: bool,
    expected: bool,
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
            value: serde_json::Value::Bool(expected),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value == expected);
}

#[cfg(test)]
mod tests {
    #[test]
    fn report_is_shape_only_and_green() {
        let report = super::build_report().unwrap();
        assert!(report.overall_pass);
        assert_eq!(
            report.pass_per_axis.get("prompt_level_reference"),
            Some(&true)
        );
        assert_eq!(
            report
                .pass_per_axis
                .get("does_not_advance_70b_reference_gate"),
            Some(&true)
        );
        assert_eq!(report.pass_per_axis.get("replay_files_valid"), Some(&true));
    }
}
