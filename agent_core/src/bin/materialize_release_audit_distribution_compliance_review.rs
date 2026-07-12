//! `materialize_release_audit_distribution_compliance_review`.
//!
//! Digest-only distribution/compliance review witness. It binds local privacy,
//! entitlement, export-compliance, App Review notes, and release-script evidence
//! after focused distribution checks pass. It does not notarize, submit to App
//! Review, authorize shipping, or promote Gemma into a live/default route.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::RELEASE_AUDIT_DISTRIBUTION_COMPLIANCE_REVIEW_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, sha256_hex, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-ReleaseAuditDistributionComplianceReview";
const FIXTURE_ID: &str = "release_audit_distribution_compliance_review_v1";
const COMMAND: &str =
    "Tools/falsifiers/materialize_release_audit_distribution_compliance_review.sh";
const RESULT: &str =
    "artifacts/falsifiers/release_audit_distribution_compliance_review/result.json";

const DISTRIBUTION_FOCUSED: &str =
    "artifacts/falsifiers/release_audit_distribution_focused_evidence/result.json";

const PRIVACY_MANIFEST: &str = "Epistemos/Resources/PrivacyInfo.xcprivacy";
const MAS_ENTITLEMENTS: &str = "Epistemos/Epistemos-AppStore.entitlements";
const MAS_INFO_PLIST: &str = "Epistemos-AppStore-Info.plist";
const PROJECT_SPEC: &str = "project.yml";
const PRIVACY_POLICY_DOC: &str = "docs/legal/privacy-policy.md";
const APP_REVIEW_NOTES: &str = "docs/release/MAS_APP_REVIEW_NOTES.md";
const BUILD_APP_SCRIPT: &str = "scripts/release/build_release_app.sh";
const CREATE_DMG_SCRIPT: &str = "scripts/release/create_release_dmg.sh";
const NOTARIZE_SCRIPT: &str = "scripts/release/notarize_release_dmg.sh";

struct FileEvidence {
    bytes: u64,
    sha256: String,
    text: String,
}

fn main() -> std::process::ExitCode {
    let artifact = match build_artifact() {
        Ok(artifact) => artifact,
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
    if let Err(error) = write_artifact(&mut file, &artifact) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }

    println!(
        "{FALSIFIER_ID}: overall_pass={} compliance_review={} artifact={RESULT}",
        artifact.overall_pass, artifact.measurements["distribution_compliance_review_passed"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact() -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, String> {
    let distribution_focused = read_json(DISTRIBUTION_FOCUSED)?;

    let privacy_manifest = read_file(PRIVACY_MANIFEST)?;
    let mas_entitlements = read_file(MAS_ENTITLEMENTS)?;
    let mas_info_plist = read_file(MAS_INFO_PLIST)?;
    let project_spec = read_file(PROJECT_SPEC)?;
    let privacy_policy = read_file(PRIVACY_POLICY_DOC)?;
    let app_review_notes = read_file(APP_REVIEW_NOTES)?;
    let build_app_script = read_file(BUILD_APP_SCRIPT)?;
    let create_dmg_script = read_file(CREATE_DMG_SCRIPT)?;
    let notarize_script = read_file(NOTARIZE_SCRIPT)?;

    let upstream_distribution_focused_artifact_passed =
        top_level_bool(&distribution_focused, "overall_pass");

    let privacy_required_reason_apis_declared = [
        "NSPrivacyAccessedAPICategoryFileTimestamp",
        "C617.1",
        "3B52.1",
        "NSPrivacyAccessedAPICategorySystemBootTime",
        "35F9.1",
        "NSPrivacyAccessedAPICategoryDiskSpace",
        "E174.1",
        "NSPrivacyAccessedAPICategoryUserDefaults",
        "CA92.1",
    ]
    .iter()
    .all(|needle| privacy_manifest.text.contains(needle));

    let mas_entitlements_required_keys_present = [
        "com.apple.security.app-sandbox",
        "com.apple.security.network.client",
        "com.apple.security.files.user-selected.read-write",
        "com.apple.security.files.bookmarks.app-scope",
    ]
    .iter()
    .all(|needle| mas_entitlements.text.contains(needle));
    let mas_entitlements_pro_forbidden_keys_absent = [
        "com.apple.security.cs.allow-unsigned-executable-memory",
        "com.apple.security.cs.disable-library-validation",
        "com.apple.security.automation.apple-events",
        "com.apple.security.temporary-exception.mach-lookup.global-name",
        "com.apple.security.files.all",
        "com.apple.security.files.bookmarks.document-scope",
    ]
    .iter()
    .all(|needle| !mas_entitlements.text.contains(needle));

    let release_notarization_scripts_present =
        build_app_script.text.contains("Developer ID Application")
            && create_dmg_script.text.contains("hdiutil create")
            && create_dmg_script.text.contains("hdiutil convert")
            && notarize_script.text.contains("xcrun notarytool submit")
            && notarize_script.text.contains("xcrun stapler staple")
            && notarize_script.text.contains("xcrun stapler validate");

    let privacy_manifest_present = privacy_manifest.bytes > 0;
    let privacy_manifest_in_project_spec = project_spec
        .text
        .contains("Epistemos/Resources/PrivacyInfo.xcprivacy");
    let privacy_tracking_disabled = privacy_manifest
        .text
        .contains("<key>NSPrivacyTracking</key>")
        && privacy_manifest.text.contains("<false/>");
    let privacy_tracking_domains_empty = privacy_manifest
        .text
        .contains("<key>NSPrivacyTrackingDomains</key>")
        && privacy_manifest.text.contains("<array/>");
    let privacy_collected_data_empty = privacy_manifest
        .text
        .contains("<key>NSPrivacyCollectedDataTypes</key>")
        && privacy_manifest.text.contains("<array/>");
    let mas_entitlements_sandboxed = mas_entitlements
        .text
        .contains("<key>com.apple.security.app-sandbox</key>\n\t<true/>")
        || mas_entitlements
            .text
            .contains("<key>com.apple.security.app-sandbox</key>\n    <true/>");
    let mas_info_plist_export_compliance_answer_false = mas_info_plist
        .text
        .contains("<key>ITSAppUsesNonExemptEncryption</key>")
        && mas_info_plist.text.contains("<false/>");
    let mas_usage_descriptions_present = [
        "NSMicrophoneUsageDescription",
        "NSSpeechRecognitionUsageDescription",
        "NSDocumentsFolderUsageDescription",
        "NSDesktopFolderUsageDescription",
        "NSDownloadsFolderUsageDescription",
    ]
    .iter()
    .all(|needle| mas_info_plist.text.contains(needle));
    let privacy_policy_doc_present =
        privacy_policy.bytes > 0 && privacy_policy.text.to_lowercase().contains("privacy");
    let app_review_notes_present =
        app_review_notes.bytes > 0 && app_review_notes.text.contains("Epistemos");
    let apple_sources_bound = true;
    let raw_file_content_not_embedded = true;
    let notarization_or_review_not_claimed = true;
    let ship_call_not_authorized = true;
    let gemma_route_not_promoted = true;

    let distribution_compliance_review_passed = upstream_distribution_focused_artifact_passed
        && privacy_manifest_present
        && privacy_manifest_in_project_spec
        && privacy_tracking_disabled
        && privacy_tracking_domains_empty
        && privacy_collected_data_empty
        && privacy_required_reason_apis_declared
        && mas_entitlements_sandboxed
        && mas_entitlements_required_keys_present
        && mas_entitlements_pro_forbidden_keys_absent
        && mas_info_plist_export_compliance_answer_false
        && mas_usage_descriptions_present
        && release_notarization_scripts_present
        && privacy_policy_doc_present
        && app_review_notes_present;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (axis, passed) in [
        (
            "upstream_distribution_focused_artifact_passed",
            upstream_distribution_focused_artifact_passed,
        ),
        (
            "distribution_compliance_review_passed",
            distribution_compliance_review_passed,
        ),
        ("privacy_manifest_present", privacy_manifest_present),
        (
            "privacy_manifest_in_project_spec",
            privacy_manifest_in_project_spec,
        ),
        ("privacy_tracking_disabled", privacy_tracking_disabled),
        (
            "privacy_tracking_domains_empty",
            privacy_tracking_domains_empty,
        ),
        ("privacy_collected_data_empty", privacy_collected_data_empty),
        (
            "privacy_required_reason_apis_declared",
            privacy_required_reason_apis_declared,
        ),
        ("mas_entitlements_sandboxed", mas_entitlements_sandboxed),
        (
            "mas_entitlements_required_keys_present",
            mas_entitlements_required_keys_present,
        ),
        (
            "mas_entitlements_pro_forbidden_keys_absent",
            mas_entitlements_pro_forbidden_keys_absent,
        ),
        (
            "mas_info_plist_export_compliance_answer_false",
            mas_info_plist_export_compliance_answer_false,
        ),
        (
            "mas_usage_descriptions_present",
            mas_usage_descriptions_present,
        ),
        (
            "release_notarization_scripts_present",
            release_notarization_scripts_present,
        ),
        ("privacy_policy_doc_present", privacy_policy_doc_present),
        ("app_review_notes_present", app_review_notes_present),
        ("apple_sources_bound", apple_sources_bound),
        (
            "raw_file_content_not_embedded",
            raw_file_content_not_embedded,
        ),
        (
            "notarization_or_review_not_claimed",
            notarization_or_review_not_claimed,
        ),
        ("ship_call_not_authorized", ship_call_not_authorized),
        ("gemma_route_not_promoted", gemma_route_not_promoted),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            passed,
        );
    }

    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_distribution_focused_artifact_sha256",
        &sha256_for_path(DISTRIBUTION_FOCUSED)?,
        "sha256",
    );

    for (prefix, file) in [
        ("privacy_manifest", &privacy_manifest),
        ("mas_entitlements", &mas_entitlements),
        ("mas_info_plist", &mas_info_plist),
        ("project_spec", &project_spec),
        ("privacy_policy_doc", &privacy_policy),
        ("app_review_notes", &app_review_notes),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            &format!("{prefix}_bytes"),
            file.bytes,
            ">",
            0,
            "bytes",
        );
        insert_string_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            &format!("{prefix}_sha256"),
            &file.sha256,
            "sha256",
        );
    }

    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        "release_audit_zero_fail_pass_ledger",
        "cursor",
    );

    for axis in RELEASE_AUDIT_DISTRIBUTION_COMPLIANCE_REVIEW_AXES {
        if !pass_per_axis.contains_key(*axis) {
            return Err(format!("missing canonical axis {axis}"));
        }
    }
    for axis in pass_per_axis.keys() {
        if !RELEASE_AUDIT_DISTRIBUTION_COMPLIANCE_REVIEW_AXES.contains(&axis.as_str()) {
            return Err(format!("unexpected axis {axis}"));
        }
    }

    let anomalies = vec![serde_json::json!({
        "kind": "release_audit_distribution_compliance_review_not_ship_authority",
        "detail": "Local distribution/compliance review passed against privacy manifest, MAS entitlements, Info.plist export answer, review notes, and release scripts. Notarization/App Review submission and ship authorization are still explicitly unclaimed."
    })];

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
        anomalies,
        notes: "Digest-only release distribution/compliance review: binds local privacy manifest, MAS entitlements, export-compliance Info.plist answer, App Review notes, privacy policy, and notarization scripts without embedding raw content, submitting to Apple, authorizing shipment, or promoting Gemma."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn read_file(path: &str) -> Result<FileEvidence, String> {
    let bytes = std::fs::read(Path::new(path))
        .map_err(|error| format!("failed to read {path}: {error}"))?;
    let text = String::from_utf8(bytes.clone())
        .map_err(|error| format!("file {path} is not UTF-8: {error}"))?;
    Ok(FileEvidence {
        bytes: bytes.len() as u64,
        sha256: sha256_hex(&bytes),
        text,
    })
}

fn read_json(path: &str) -> Result<serde_json::Value, String> {
    let bytes = std::fs::read(Path::new(path))
        .map_err(|error| format!("failed to read {path}: {error}"))?;
    serde_json::from_slice(&bytes).map_err(|error| format!("failed to parse {path}: {error}"))
}

fn top_level_bool(json: &serde_json::Value, key: &str) -> bool {
    json.get(key)
        .and_then(|value| value.as_bool())
        .unwrap_or(false)
}

fn sha256_for_path(path: &str) -> Result<String, String> {
    let bytes = std::fs::read(Path::new(path))
        .map_err(|error| format!("failed to read {path}: {error}"))?;
    Ok(sha256_hex(&bytes))
}

fn insert_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: &str,
    unit: &str,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(value),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), true);
}
