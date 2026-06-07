//! `falsify_litertlm_native_swift_admission`
//!
//! Metadata-only witness for `F-LiteRTLM-NativeSwiftAdmission`. It turns
//! LiteRT-LM Swift/macOS package evidence into an admission card before
//! LiteRT-LM can influence RuntimeRouter/System G. No package, binary, model,
//! runtime, provider, or server bytes are downloaded, linked, loaded, or run.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    LiteRtMasVerdict, LiteRtNativeSwiftAdmissionCard, LiteRtNativeSwiftAdmissionError,
    LiteRtNativeSwiftAdmissionSet, LiteRtSwiftAdmissionProofRefs, LiteRtSwiftBinaryTarget,
    LiteRtSwiftByteScope, LiteRtSwiftPlatform, ProStatus, ProductBuild,
    LITERTLM_NATIVE_SWIFT_ADMISSION_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-LiteRTLM-NativeSwiftAdmission";
const FIXTURE_ID: &str = "litertlm_native_swift_admission_v1";
const COMMAND: &str = "Tools/falsifiers/f_litertlm_native_swift_admission.sh";
const RESULT: &str = "artifacts/falsifiers/litertlm_native_swift_admission/result.json";
const CREATED_AT_MS: u64 = 1_779_055_900_000;
const SET_METADATA_BYTES: u64 = 92_000;

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
        "{FALSIFIER_ID}: overall_pass={} binary_target_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["binary_target_count"].value,
        artifact.measurements["red_fixture_rejection_count"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let card = accepted_card();
    let set =
        LiteRtNativeSwiftAdmissionSet::new(vec![card.clone()], SET_METADATA_BYTES, CREATED_AT_MS)?;
    let reversed =
        LiteRtNativeSwiftAdmissionSet::new(vec![card.clone()], SET_METADATA_BYTES, CREATED_AT_MS)?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&card);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "accepted_admission_card_present",
            metrics.card_count == 1
                && card.card_id == "litertlm_v0_13_1_swift_package_admission"
                && card.license_spdx == "Apache-2.0",
        ),
        (
            "official_sources_bound",
            card.repo_url == "https://github.com/google-ai-edge/LiteRT-LM"
                && card.package_url.ends_with("/Package.swift")
                && card.swift_doc_url == "https://ai.google.dev/edge/litert-lm/swift"
                && card.release_url.ends_with("/v0.13.1"),
        ),
        (
            "ios_and_macos_binary_targets_bound",
            metrics.binary_target_count == 2
                && metrics.platform_count == 2
                && red_pass(&red_results, "missing_ios_binary_target")
                && red_pass(&red_results, "missing_macos_binary_target"),
        ),
        (
            "binary_checksums_bound",
            card.binary_targets
                .iter()
                .all(|target| target.checksum.len() == 64)
                && red_pass(&red_results, "bad_binary_checksum"),
        ),
        (
            "declared_binary_asset_bytes_bound",
            metrics.declared_binary_asset_bytes == 123_675_099
                && red_pass(&red_results, "missing_declared_asset_bytes"),
        ),
        (
            "unsafe_linker_review_required",
            metrics.unsafe_linker_flag_count == 2
                && card
                    .unsafe_linker_flags
                    .iter()
                    .any(|flag| flag == "-all_load")
                && card.unsafe_linker_review_required
                && red_pass(&red_results, "missing_unsafe_linker_flag")
                && red_pass(&red_results, "unsafe_linker_review_missing"),
        ),
        (
            "prebuilt_binary_review_required",
            card.prebuilt_binary_review_required
                && red_pass(&red_results, "prebuilt_binary_review_missing"),
        ),
        (
            "pro_research_mas_denied",
            card.product_build == ProductBuild::Pro
                && card.pro_status == ProStatus::ResearchCandidate
                && card.mas_verdict == LiteRtMasVerdict::DeniedUntilBinaryReview
                && red_pass(&red_results, "mas_live_claim")
                && red_pass(&red_results, "pro_status_live_claim"),
        ),
        (
            "server_sidecar_default_denied",
            card.openai_server_signal
                && card.server_sidecar_default_denied
                && red_pass(&red_results, "server_sidecar_not_denied"),
        ),
        (
            "required_witnesses_bound",
            card.cancellation_witness_required
                && card.tool_schema_witness_required
                && card.answer_packet_witness_required
                && card.rollback_witness_required
                && red_pass(&red_results, "missing_cancellation_witness")
                && red_pass(&red_results, "missing_tool_schema_witness")
                && red_pass(&red_results, "missing_answer_packet_witness")
                && red_pass(&red_results, "missing_rollback_witness"),
        ),
        (
            "proof_refs_bound",
            card.proof_refs.falsifier_ref.starts_with("falsifier:")
                && card.proof_refs.rollback_ref.starts_with("rollback:")
                && card
                    .proof_refs
                    .run_event_log_ref
                    .starts_with("run_event_log:")
                && card
                    .proof_refs
                    .answer_packet_ref
                    .starts_with("answer_packet:")
                && card
                    .proof_refs
                    .binary_provenance_ref
                    .starts_with("binary_provenance:")
                && red_pass(&red_results, "bad_proof_ref_prefix"),
        ),
        (
            "zero_package_binary_runtime_model_bytes",
            metrics.package_bytes_downloaded == 0
                && metrics.binary_asset_bytes_downloaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.model_bytes_loaded == 0
                && red_pass(&red_results, "package_bytes_downloaded")
                && red_pass(&red_results, "binary_asset_bytes_downloaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "model_bytes_loaded"),
        ),
        (
            "zero_provider_and_product_copy",
            metrics.provider_calls_made == 0
                && metrics.product_files_copied == 0
                && red_pass(&red_results, "provider_call_made")
                && red_pass(&red_results, "product_file_copied"),
        ),
        (
            "no_import_or_resolution",
            metrics.product_dependency_imported_count == 0
                && metrics.package_resolved_count == 0
                && metrics.binary_downloaded_count == 0
                && metrics.runtime_loaded_count == 0
                && metrics.model_loaded_count == 0
                && red_pass(&red_results, "product_dependency_imported")
                && red_pass(&red_results, "package_resolved")
                && red_pass(&red_results, "binary_downloaded")
                && red_pass(&red_results, "runtime_loaded")
                && red_pass(&red_results, "model_loaded"),
        ),
        (
            "no_l2_l3_or_large_model_claim",
            metrics.l2_l3_promotion_claim_count == 0
                && metrics.live_dense_70b_claim_count == 0
                && metrics.hidden_route_authority_count == 0
                && red_pass(&red_results, "l2_l3_promotion_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "hidden_route_authority"),
        ),
        (
            "next_cursor_bound",
            LITERTLM_NATIVE_SWIFT_ADMISSION_NEXT_CURSOR == "gemma4_mtp_drafter_compatibility_card",
        ),
        (
            "litertlm_native_swift_admission_address_deterministic",
            set.set_address == reversed.set_address,
        ),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            pass,
        );
    }

    for (name, pass) in &red_results {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            *pass,
        );
    }

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "admission_card_count",
        metrics.card_count,
        "==",
        1,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "binary_target_count",
        metrics.binary_target_count,
        "==",
        2,
        "targets",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "platform_count",
        metrics.platform_count,
        "==",
        2,
        "platforms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unsafe_linker_flag_count",
        metrics.unsafe_linker_flag_count,
        ">=",
        1,
        "flags",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "declared_binary_asset_bytes",
        metrics.declared_binary_asset_bytes,
        ">=",
        1,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        ">=",
        30,
        "fixtures",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes_read",
        metrics.metadata_bytes_read,
        "<=",
        128 * 1024,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_bytes_loaded",
        metrics.runtime_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_bytes_loaded",
        metrics.model_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    measurements.insert(
        "litertlm_native_swift_admission_address".to_string(),
        Measurement {
            value: serde_json::Value::String(set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "litertlm_native_swift_admission_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert("litertlm_native_swift_admission_address".to_string(), true);

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: Vec::new(),
        notes: "Builds F-LiteRTLM-NativeSwiftAdmission from official LiteRT-LM repo, Package.swift, release assets, Swift docs, and Pass 65 canon. Scope is T1/L1 metadata only: LiteRT-LM can feed later MTP/lane-tournament/runtime probes, but this witness imports no package, downloads no binary, loads no runtime/model bytes, starts no server, and promotes no MAS/L2/L3 capability.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn accepted_card() -> LiteRtNativeSwiftAdmissionCard {
    LiteRtNativeSwiftAdmissionCard {
        card_id: "litertlm_v0_13_1_swift_package_admission".to_string(),
        repo_url: "https://github.com/google-ai-edge/LiteRT-LM".to_string(),
        package_url: "https://github.com/google-ai-edge/LiteRT-LM/blob/main/Package.swift"
            .to_string(),
        swift_doc_url: "https://ai.google.dev/edge/litert-lm/swift".to_string(),
        release_url: "https://github.com/google-ai-edge/LiteRT-LM/releases/tag/v0.13.1"
            .to_string(),
        license_spdx: "Apache-2.0".to_string(),
        release_tag: "v0.13.1".to_string(),
        repo_pushed_at: "2026-06-06T04:28:05Z".to_string(),
        binary_targets: vec![
            LiteRtSwiftBinaryTarget {
                name: "CLiteRTLM".to_string(),
                platform: LiteRtSwiftPlatform::Ios,
                url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.13.1/CLiteRTLM.xcframework.zip".to_string(),
                checksum: "7ff01c42106b754748b5dd3036a4a57161b25ebf523e705bebc1219061852362".to_string(),
                release_tag: "v0.13.1".to_string(),
                declared_asset_bytes: 80_754_584,
            },
            LiteRtSwiftBinaryTarget {
                name: "CLiteRTLM_mac".to_string(),
                platform: LiteRtSwiftPlatform::Macos,
                url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.13.1/CLiteRTLM_mac.xcframework.zip".to_string(),
                checksum: "ec9ffe230dc39117a7fc8933b1cc15910454027fee6d3041534ab7cf17313981".to_string(),
                release_tag: "v0.13.1".to_string(),
                declared_asset_bytes: 42_920_515,
            },
        ],
        unsafe_linker_flags: vec!["-Xlinker".to_string(), "-all_load".to_string()],
        swift_package_signal: true,
        native_macos_signal: true,
        metal_gpu_signal: true,
        tool_use_signal: true,
        multimodal_signal: true,
        openai_server_signal: true,
        server_sidecar_default_denied: true,
        prebuilt_binary_review_required: true,
        unsafe_linker_review_required: true,
        cancellation_witness_required: true,
        tool_schema_witness_required: true,
        answer_packet_witness_required: true,
        rollback_witness_required: true,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        mas_verdict: LiteRtMasVerdict::DeniedUntilBinaryReview,
        byte_scope: LiteRtSwiftByteScope::metadata_only(64_000),
        proof_refs: LiteRtSwiftAdmissionProofRefs {
            falsifier_ref: "falsifier:F-LiteRTLM-NativeSwiftAdmission".to_string(),
            rollback_ref: "rollback:litertlm-admission-default-off".to_string(),
            run_event_log_ref: "run_event_log:litertlm-admission-source-card".to_string(),
            answer_packet_ref: "answer_packet:litertlm-admission-visible-caveat".to_string(),
            admission_ref: "admission:scope-rex-litertlm-native-swift".to_string(),
            scope_rex_ref: "scope_rex:litertlm-native-swift-deny-by-default".to_string(),
            sovereign_gate_ref: "sovereign_gate:litertlm-mas-pro-boundary".to_string(),
            compatibility_fence_ref: "compat:litertlm-v0-13-1-swift-package".to_string(),
            binary_provenance_ref: "binary_provenance:litertlm-v0-13-1-xcframeworks"
                .to_string(),
            mas_pro_boundary_ref: "mas_pro:litertlm-pro-research-only".to_string(),
        },
        product_dependency_imported: false,
        package_resolved: false,
        binary_downloaded: false,
        runtime_loaded: false,
        model_loaded: false,
        l2_l3_promotion_claim: false,
        live_dense_70b_claim: false,
        hidden_route_authority: false,
    }
}

fn red_fixture_results(card: &LiteRtNativeSwiftAdmissionCard) -> Vec<(&'static str, bool)> {
    vec![
        red(
            card,
            "missing_ios_binary_target_rejected",
            |c| {
                c.binary_targets
                    .retain(|target| target.platform != LiteRtSwiftPlatform::Ios);
            },
            LiteRtNativeSwiftAdmissionError::MissingIosBinaryTarget,
        ),
        red(
            card,
            "missing_macos_binary_target_rejected",
            |c| {
                c.binary_targets
                    .retain(|target| target.platform != LiteRtSwiftPlatform::Macos);
            },
            LiteRtNativeSwiftAdmissionError::MissingMacosBinaryTarget,
        ),
        red(
            card,
            "duplicate_binary_target_rejected",
            |c| {
                c.binary_targets.push(c.binary_targets[0].clone());
            },
            LiteRtNativeSwiftAdmissionError::DuplicateBinaryTarget("CLiteRTLM".to_string()),
        ),
        red(
            card,
            "bad_binary_checksum_rejected",
            |c| {
                c.binary_targets[0].checksum = "not-a-checksum".to_string();
            },
            LiteRtNativeSwiftAdmissionError::BadBinaryChecksum("CLiteRTLM".to_string()),
        ),
        red(
            card,
            "missing_declared_asset_bytes_rejected",
            |c| {
                c.binary_targets[0].declared_asset_bytes = 0;
            },
            LiteRtNativeSwiftAdmissionError::MissingDeclaredAssetBytes("CLiteRTLM".to_string()),
        ),
        red(
            card,
            "missing_unsafe_linker_flag_rejected",
            |c| {
                c.unsafe_linker_flags.clear();
            },
            LiteRtNativeSwiftAdmissionError::MissingUnsafeLinkerFlag,
        ),
        red(
            card,
            "unsafe_linker_review_missing_rejected",
            |c| {
                c.unsafe_linker_review_required = false;
            },
            LiteRtNativeSwiftAdmissionError::UnsafeLinkerReviewMissing,
        ),
        red(
            card,
            "prebuilt_binary_review_missing_rejected",
            |c| {
                c.prebuilt_binary_review_required = false;
            },
            LiteRtNativeSwiftAdmissionError::PrebuiltBinaryReviewMissing,
        ),
        red(
            card,
            "mas_live_claim_rejected",
            |c| {
                c.product_build = ProductBuild::Mas;
            },
            LiteRtNativeSwiftAdmissionError::ProductBuildNotPro,
        ),
        red(
            card,
            "pro_status_live_claim_rejected",
            |c| {
                c.pro_status = ProStatus::Live;
            },
            LiteRtNativeSwiftAdmissionError::ProStatusNotResearchCandidate,
        ),
        red(
            card,
            "server_sidecar_not_denied_rejected",
            |c| {
                c.server_sidecar_default_denied = false;
            },
            LiteRtNativeSwiftAdmissionError::ServerSidecarNotDenied,
        ),
        red(
            card,
            "missing_cancellation_witness_rejected",
            |c| {
                c.cancellation_witness_required = false;
            },
            LiteRtNativeSwiftAdmissionError::MissingCancellationWitness,
        ),
        red(
            card,
            "missing_tool_schema_witness_rejected",
            |c| {
                c.tool_schema_witness_required = false;
            },
            LiteRtNativeSwiftAdmissionError::MissingToolSchemaWitness,
        ),
        red(
            card,
            "missing_answer_packet_witness_rejected",
            |c| {
                c.answer_packet_witness_required = false;
            },
            LiteRtNativeSwiftAdmissionError::MissingAnswerPacketWitness,
        ),
        red(
            card,
            "missing_rollback_witness_rejected",
            |c| {
                c.rollback_witness_required = false;
            },
            LiteRtNativeSwiftAdmissionError::MissingRollbackWitness,
        ),
        red(
            card,
            "bad_proof_ref_prefix_rejected",
            |c| {
                c.proof_refs.answer_packet_ref = "missing-prefix".to_string();
            },
            LiteRtNativeSwiftAdmissionError::BadProofRefPrefix("answer_packet_ref"),
        ),
        red(
            card,
            "non_https_url_rejected",
            |c| {
                c.package_url = "http://github.com/google-ai-edge/LiteRT-LM".to_string();
            },
            LiteRtNativeSwiftAdmissionError::NonHttpsUrl(
                "http://github.com/google-ai-edge/LiteRT-LM".to_string(),
            ),
        ),
        red(
            card,
            "unsupported_license_rejected",
            |c| {
                c.license_spdx = "NOASSERTION".to_string();
            },
            LiteRtNativeSwiftAdmissionError::UnsupportedLicense("NOASSERTION".to_string()),
        ),
        red(
            card,
            "bad_release_tag_rejected",
            |c| {
                c.release_tag = "main".to_string();
            },
            LiteRtNativeSwiftAdmissionError::BadReleaseTag("main".to_string()),
        ),
        red(
            card,
            "product_dependency_imported_rejected",
            |c| {
                c.product_dependency_imported = true;
            },
            LiteRtNativeSwiftAdmissionError::ProductDependencyImported,
        ),
        red(
            card,
            "package_resolved_rejected",
            |c| {
                c.package_resolved = true;
            },
            LiteRtNativeSwiftAdmissionError::PackageResolved,
        ),
        red(
            card,
            "binary_downloaded_rejected",
            |c| {
                c.binary_downloaded = true;
            },
            LiteRtNativeSwiftAdmissionError::BinaryDownloaded,
        ),
        red(
            card,
            "runtime_loaded_rejected",
            |c| {
                c.runtime_loaded = true;
            },
            LiteRtNativeSwiftAdmissionError::RuntimeLoaded,
        ),
        red(
            card,
            "model_loaded_rejected",
            |c| {
                c.model_loaded = true;
            },
            LiteRtNativeSwiftAdmissionError::ModelLoaded,
        ),
        red(
            card,
            "package_bytes_downloaded_rejected",
            |c| {
                c.byte_scope.package_bytes_downloaded = 1;
            },
            LiteRtNativeSwiftAdmissionError::PackageBytesDownloaded,
        ),
        red(
            card,
            "binary_asset_bytes_downloaded_rejected",
            |c| {
                c.byte_scope.binary_asset_bytes_downloaded = 1;
            },
            LiteRtNativeSwiftAdmissionError::BinaryAssetBytesDownloaded,
        ),
        red(
            card,
            "runtime_bytes_loaded_rejected",
            |c| {
                c.byte_scope.runtime_bytes_loaded = 1;
            },
            LiteRtNativeSwiftAdmissionError::RuntimeBytesLoaded,
        ),
        red(
            card,
            "model_bytes_loaded_rejected",
            |c| {
                c.byte_scope.model_bytes_loaded = 1;
            },
            LiteRtNativeSwiftAdmissionError::ModelBytesLoaded,
        ),
        red(
            card,
            "provider_call_made_rejected",
            |c| {
                c.byte_scope.provider_calls_made = 1;
            },
            LiteRtNativeSwiftAdmissionError::ProviderCallMade,
        ),
        red(
            card,
            "product_file_copied_rejected",
            |c| {
                c.byte_scope.product_files_copied = 1;
            },
            LiteRtNativeSwiftAdmissionError::ProductFileCopied,
        ),
        red(
            card,
            "l2_l3_promotion_claim_rejected",
            |c| {
                c.l2_l3_promotion_claim = true;
            },
            LiteRtNativeSwiftAdmissionError::L2L3PromotionClaim,
        ),
        red(
            card,
            "live_dense_70b_claim_rejected",
            |c| {
                c.live_dense_70b_claim = true;
            },
            LiteRtNativeSwiftAdmissionError::LiveDense70BClaim,
        ),
        red(
            card,
            "hidden_route_authority_rejected",
            |c| {
                c.hidden_route_authority = true;
            },
            LiteRtNativeSwiftAdmissionError::HiddenRouteAuthority,
        ),
    ]
}

fn red(
    base: &LiteRtNativeSwiftAdmissionCard,
    name: &'static str,
    mutate: impl FnOnce(&mut LiteRtNativeSwiftAdmissionCard),
    expected: LiteRtNativeSwiftAdmissionError,
) -> (&'static str, bool) {
    let mut card = base.clone();
    mutate(&mut card);
    let passed =
        match LiteRtNativeSwiftAdmissionSet::new(vec![card], SET_METADATA_BYTES, CREATED_AT_MS) {
            Err(error) => error == expected,
            Ok(_) => false,
        };
    (name, passed)
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    let rejected_name = format!("{name}_rejected");
    results
        .iter()
        .find(|(candidate, _)| *candidate == name || *candidate == rejected_name.as_str())
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepted_fixture_passes_all_axes() {
        let artifact = build_artifact().unwrap();
        assert!(artifact.overall_pass);
        assert_eq!(artifact.measurements["binary_target_count"].value, 2);
        assert_eq!(artifact.measurements["runtime_bytes_loaded"].value, 0);
        assert_eq!(artifact.measurements["model_bytes_loaded"].value, 0);
    }

    #[test]
    fn red_fixture_pack_rejects_unsafe_promotions() {
        let card = accepted_card();
        let results = red_fixture_results(&card);
        assert!(red_pass(&results, "mas_live_claim"));
        assert!(red_pass(&results, "product_dependency_imported"));
        assert!(red_pass(&results, "runtime_bytes_loaded"));
        assert!(red_pass(&results, "l2_l3_promotion_claim"));
        assert_eq!(
            results.iter().filter(|(_, pass)| *pass).count(),
            results.len()
        );
    }
}
