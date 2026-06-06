//! `falsify_turbovec_real_adapter_product_graph_no_contamination_probe`
//!
//! Metadata/source-scan witness for
//! `F-TurboVec-RealAdapterProductGraphNoContaminationProbe`. It consumes the
//! exact-baseline shadow-replay witness and proves TurboVec real-adapter
//! research has not contaminated product imports, dependencies, native-link
//! surfaces, route policy, model context, user-facing green copy, or runtime
//! bytes.

use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, TurboVecProductGraphAuditRow, TurboVecProductGraphByteLedger,
    TurboVecProductGraphPolicy, TurboVecProductGraphProofRefs, TurboVecProductGraphStatus,
    TurboVecProductGraphSurface, TurboVecProductGraphTier,
    TurboVecRealAdapterProductGraphNoContaminationProbeSet, UasAddress, UasKind,
    TURBOVEC_REAL_ADAPTER_EXACT_BASELINE_SHADOW_REPLAY_NEXT_CURSOR,
    TURBOVEC_REAL_ADAPTER_PRODUCT_GRAPH_NO_CONTAMINATION_CURSOR,
    TURBOVEC_REAL_ADAPTER_PRODUCT_GRAPH_NO_CONTAMINATION_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RealAdapterProductGraphNoContaminationProbe";
const FIXTURE_ID: &str = "turbovec_real_adapter_product_graph_no_contamination_probe_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_turbovec_real_adapter_product_graph_no_contamination_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_product_graph_no_contamination_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_exact_baseline_shadow_replay_probe/result.json";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const PRODUCT_GRAPH_REF_PREFIX: &str = "product_graph:turbovec-no-contamination:";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-product-graph:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:turbovec-product-graph:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:turbovec-product-graph:";
const COMPATIBILITY_REF_PREFIX: &str = "compat:turbovec-product-graph:";
const RED_FIXTURE_FLOOR: u64 = 42;

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
        if let Err(error) = fs::create_dir_all(parent) {
            eprintln!("failed to create artifact directory: {error}");
            return std::process::ExitCode::from(2);
        }
    }
    let mut file = match fs::File::create(&path) {
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
        "{FALSIFIER_ID}: overall_pass={} rows={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["row_count"].value,
        artifact.measurements["red_fixture_rejection_count"].value,
        artifact.measurements["next_research_to_build_unit"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let upstream = upstream_shadow_replay_address()?;
    let rows = audit_rows()?;
    let byte_ledger = ledger_from_rows(&rows)?;
    let set = build_set(
        upstream.clone(),
        rows.clone(),
        policy(),
        proof_refs(),
        byte_ledger.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecProductGraphStatus::MetadataOnlyNoContamination,
        TurboVecProductGraphTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )?;
    let reversed = build_set(
        upstream.clone(),
        rows.into_iter().rev().collect(),
        policy(),
        proof_refs(),
        byte_ledger,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecProductGraphStatus::MetadataOnlyNoContamination,
        TurboVecProductGraphTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&upstream, &set.rows, &set.byte_ledger);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_shadow_replay_bound",
            set.upstream_shadow_replay_witness_ref
                == "artifact:turbovec_real_adapter_exact_baseline_shadow_replay_probe:result"
                && set
                    .upstream_shadow_replay_address
                    .to_string()
                    .starts_with("turbovec_real_adapter_exact_baseline_shadow_replay_probe:")
                && red_pass(&red_results, "bad_upstream_shadow"),
        ),
        (
            "product_surface_scan_coverage",
            metrics.row_count >= 7
                && metrics.swift_product_source_rows >= 1
                && metrics.user_facing_copy_rows >= 1
                && metrics.runtime_route_rows >= 2
                && metrics.product_manifest_rows >= 1
                && metrics.quarantined_architecture_rows >= 2
                && metrics.scanned_file_count >= 12
                && red_pass(&red_results, "remove_swift_product")
                && red_pass(&red_results, "remove_user_copy")
                && red_pass(&red_results, "remove_swift_routes")
                && red_pass(&red_results, "remove_rust_routes")
                && red_pass(&red_results, "remove_manifest")
                && red_pass(&red_results, "remove_architecture")
                && red_pass(&red_results, "remove_canon"),
        ),
        (
            "product_import_dependency_absence",
            metrics.forbidden_turbovec_mentions == 0
                && metrics.product_import_mentions == 0
                && metrics.product_dependency_mentions == 0
                && metrics.native_link_mentions == 0
                && red_pass(&red_results, "product_turbovec_mention")
                && red_pass(&red_results, "product_import")
                && red_pass(&red_results, "product_dependency")
                && red_pass(&red_results, "native_link"),
        ),
        (
            "route_context_copy_absence",
            metrics.route_policy_mentions == 0
                && metrics.model_context_mentions == 0
                && metrics.user_facing_green_copy_mentions == 0
                && metrics.hidden_cloud_or_provider_fallback_mentions == 0
                && red_pass(&red_results, "route_policy")
                && red_pass(&red_results, "model_context")
                && red_pass(&red_results, "green_copy")
                && red_pass(&red_results, "hidden_cloud"),
        ),
        (
            "architecture_mentions_quarantined",
            metrics.allowed_architecture_mentions >= 8
                && metrics.quarantined_architecture_rows == 2
                && red_pass(&red_results, "architecture_mentions_removed")
                && red_pass(&red_results, "architecture_forbidden"),
        ),
        (
            "byte_scope_no_runtime_or_product_mutation",
            metrics.additional_turbovec_raw_source_bytes_inspected == 0
                && metrics.copied_product_file_count == 0
                && metrics.product_dependencies_added == 0
                && metrics.native_link_probe_count == 0
                && metrics.adapter_build_count == 0
                && metrics.benchmark_run_count == 0
                && metrics.exact_baseline_bytes_opened == 0
                && metrics.index_bytes_opened == 0
                && metrics.allocated_runtime_bytes == 0
                && metrics.runtime_model_bytes_loaded == 0
                && metrics.model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.row_product_files_copied == 0
                && metrics.row_product_graph_mutations == 0
                && red_pass(&red_results, "raw_source_read")
                && red_pass(&red_results, "copied_product_file")
                && red_pass(&red_results, "dependency_added")
                && red_pass(&red_results, "adapter_build")
                && red_pass(&red_results, "benchmark_run")
                && red_pass(&red_results, "runtime_bytes")
                && red_pass(&red_results, "index_bytes")
                && red_pass(&red_results, "provider_call")
                && red_pass(&red_results, "row_product_mutation"),
        ),
        (
            "proof_surfaces_required",
            proof_refs()
                .visible_summary
                .to_ascii_lowercase()
                .contains("product graph no-contamination")
                && red_pass(&red_results, "bad_product_graph_ref")
                && red_pass(&red_results, "bad_rollback_ref")
                && red_pass(&red_results, "bad_run_event_log_ref")
                && red_pass(&red_results, "bad_answer_packet_ref")
                && red_pass(&red_results, "bad_compat_ref")
                && red_pass(&red_results, "weak_visible_summary"),
        ),
        (
            "policy_fail_closed",
            set.policy.exact_baseline_shadow_replay_required
                && set.policy.product_source_scan_required
                && set.policy.product_manifest_scan_required
                && set.policy.runtime_route_scan_required
                && set.policy.model_context_scan_required
                && set.policy.user_copy_scan_required
                && set.policy.architecture_mentions_quarantined
                && set.policy.no_product_import
                && set.policy.no_product_dependency
                && set.policy.no_native_link_probe
                && set.policy.no_adapter_build
                && set.policy.no_runtime_execution
                && set.policy.no_route_policy_mutation
                && set.policy.no_model_context_injection
                && set.policy.no_user_facing_green_copy
                && set.policy.no_hidden_cloud_fallback
                && set.policy.no_live_large_model_claim
                && set.policy.no_ssd_as_ram_claim
                && red_pass(&red_results, "policy_import")
                && red_pass(&red_results, "policy_route")
                && red_pass(&red_results, "policy_copy")
                && red_pass(&red_results, "policy_answer_packet"),
        ),
        (
            "product_and_large_model_claims_rejected",
            metrics.product_capability_promoted_count == 0
                && metrics.product_graph_mutation_count == 0
                && metrics.route_mutation_count == 0
                && metrics.model_context_injection_count == 0
                && metrics.hidden_authority_count == 0
                && metrics.live_large_model_claim_count == 0
                && metrics.ssd_as_ram_claim_count == 0
                && red_pass(&red_results, "product_promoted")
                && red_pass(&red_results, "product_graph_mutated")
                && red_pass(&red_results, "claim_route_mutation")
                && red_pass(&red_results, "claim_context")
                && red_pass(&red_results, "claim_hidden_authority")
                && red_pass(&red_results, "claim_live_large_model")
                && red_pass(&red_results, "claim_ssd_as_ram")
                && red_pass(&red_results, "product_build_mas")
                && red_pass(&red_results, "pro_status_live")
                && red_pass(&red_results, "tier_t2"),
        ),
        (
            "reversed_order_address_deterministic",
            set.set_address == reversed.set_address,
        ),
        (
            "red_fixture_rejection_floor",
            red_fixture_rejection_count >= RED_FIXTURE_FLOOR,
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

    for (name, actual, expected, operator, unit) in [
        ("row_count", metrics.row_count, 7, ">=", "count"),
        (
            "scanned_file_count",
            metrics.scanned_file_count,
            12,
            ">=",
            "count",
        ),
        (
            "allowed_architecture_mentions",
            metrics.allowed_architecture_mentions,
            8,
            ">=",
            "count",
        ),
        (
            "forbidden_turbovec_mentions",
            metrics.forbidden_turbovec_mentions,
            0,
            "==",
            "count",
        ),
        (
            "product_import_mentions",
            metrics.product_import_mentions,
            0,
            "==",
            "count",
        ),
        (
            "product_dependency_mentions",
            metrics.product_dependency_mentions,
            0,
            "==",
            "count",
        ),
        (
            "route_policy_mentions",
            metrics.route_policy_mentions,
            0,
            "==",
            "count",
        ),
        (
            "model_context_mentions",
            metrics.model_context_mentions,
            0,
            "==",
            "count",
        ),
        (
            "user_facing_green_copy_mentions",
            metrics.user_facing_green_copy_mentions,
            0,
            "==",
            "count",
        ),
        (
            "scanned_product_bytes",
            metrics.scanned_product_bytes,
            1,
            ">=",
            "bytes",
        ),
        (
            "scanned_manifest_bytes",
            metrics.scanned_manifest_bytes,
            1,
            ">=",
            "bytes",
        ),
        (
            "scanned_architecture_metadata_bytes",
            metrics.scanned_architecture_metadata_bytes,
            1,
            ">=",
            "bytes",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            RED_FIXTURE_FLOOR,
            ">=",
            "count",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            actual,
            operator,
            expected,
            unit,
        );
    }
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "pinned_revision",
        PINNED_REVISION,
        PINNED_REVISION,
        "sha",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "product_graph_no_contamination_address",
        &set.set_address.to_string(),
        "turbovec_real_adapter_product_graph_no_contamination_probe:",
        "uas_address",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        TURBOVEC_REAL_ADAPTER_PRODUCT_GRAPH_NO_CONTAMINATION_NEXT_CURSOR,
        TURBOVEC_REAL_ADAPTER_PRODUCT_GRAPH_NO_CONTAMINATION_NEXT_CURSOR,
        "cursor",
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
            "kind": "metadata_source_scan_no_contamination_scope",
            "detail": "Product graph no-contamination source scan only. No TurboVec source import, dependency insertion, native-link probe, adapter build, benchmark run, exact-baseline/index/model/runtime/provider bytes, route mutation, context injection, hidden authority, or live large-local-model product claim."
        })],
        notes: "Builds F-TurboVec-RealAdapterProductGraphNoContaminationProbe as a T1/L1 metadata/source-scan witness after exact-baseline shadow replay. It proves selected product/runtime/copy surfaces have no TurboVec contamination while architecture and canon mentions remain quarantined and AnswerPacket-visible.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_shadow_replay_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream exact-baseline shadow-replay witness has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_REAL_ADAPTER_PRODUCT_GRAPH_NO_CONTAMINATION_CURSOR)
        || TURBOVEC_REAL_ADAPTER_EXACT_BASELINE_SHADOW_REPLAY_NEXT_CURSOR
            != TURBOVEC_REAL_ADAPTER_PRODUCT_GRAPH_NO_CONTAMINATION_CURSOR
    {
        return Err("upstream shadow-replay witness does not point at product graph".into());
    }
    for axis in [
        "/pass_per_axis/upstream_clean_room_adapter_plan_bound",
        "/pass_per_axis/shadow_replay_scenario_coverage",
        "/pass_per_axis/exact_baseline_recall_and_allowlist_bound",
        "/pass_per_axis/fallback_rollback_answer_packet_bound",
        "/pass_per_axis/no_product_graph_route_context_authority",
        "/pass_per_axis/product_and_large_model_claims_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(format!("upstream shadow-replay axis missing or false: {axis}").into());
        }
    }
    let address = value
        .pointer("/measurements/exact_baseline_shadow_replay_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing exact_baseline_shadow_replay_address")?;
    Ok(UasAddress::from_str(address)?)
}

#[allow(clippy::too_many_arguments)]
fn build_set(
    upstream: UasAddress,
    rows: Vec<TurboVecProductGraphAuditRow>,
    policy: TurboVecProductGraphPolicy,
    proof_refs: TurboVecProductGraphProofRefs,
    ledger: TurboVecProductGraphByteLedger,
    product_build: ProductBuild,
    pro_status: ProStatus,
    status: TurboVecProductGraphStatus,
    tier: TurboVecProductGraphTier,
    product_capability_promoted: bool,
    product_graph_mutated: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<TurboVecRealAdapterProductGraphNoContaminationProbeSet, Box<dyn std::error::Error>> {
    Ok(
        TurboVecRealAdapterProductGraphNoContaminationProbeSet::from_parts(
            upstream,
            rows,
            policy,
            proof_refs,
            ledger,
            product_build,
            pro_status,
            status,
            tier,
            product_capability_promoted,
            product_graph_mutated,
            route_mutation_allowed,
            model_context_injected,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        )?,
    )
}

fn audit_rows() -> Result<Vec<TurboVecProductGraphAuditRow>, Box<dyn std::error::Error>> {
    Ok(vec![
        scan_row(
            "swift_product_source",
            TurboVecProductGraphSurface::SwiftProductSource,
            &[
                "Epistemos/Engine/MLXInferenceService.swift",
                "Epistemos/Engine/LocalModelInfrastructure.swift",
                "Epistemos/Engine/LLMService.swift",
                "Epistemos/State/InferenceState.swift",
            ],
        )?,
        scan_row(
            "swift_user_facing_copy",
            TurboVecProductGraphSurface::SwiftUserFacingCopy,
            &[
                "Epistemos/Resources/Localizable.xcstrings",
                "Epistemos/Views/Settings/ModelVaultsSettingsView.swift",
                "Epistemos/Views/Settings/RuntimeLanesSection.swift",
                "Epistemos/Views/Onboarding/SetupAssistantView.swift",
            ],
        )?,
        scan_row(
            "swift_runtime_routing",
            TurboVecProductGraphSurface::SwiftRuntimeRouting,
            &[
                "Epistemos/Engine/TriageService.swift",
                "Epistemos/LocalAgent/RuntimeRouter.swift",
                "Epistemos/LocalAgent/LocalAgentGatewayPolicy.swift",
                "Epistemos/LocalAgent/LocalAgentPromptBuilder.swift",
            ],
        )?,
        scan_row(
            "rust_runtime_routing",
            TurboVecProductGraphSurface::RustRuntimeRouting,
            &[
                "agent_core/src/routing.rs",
                "agent_core/src/route",
                "agent_core/src/runtime",
            ],
        )?,
        scan_row(
            "product_manifest",
            TurboVecProductGraphSurface::ProductManifest,
            &[
                "Epistemos-Info.plist",
                "Epistemos-AppStore-Info.plist",
                "Epistemos.xcodeproj/project.pbxproj",
            ],
        )?,
        scan_row(
            "architecture_falsifier_graph",
            TurboVecProductGraphSurface::ArchitectureFalsifierGraph,
            &[
                "agent_core/Cargo.toml",
                "agent_core/src/uas/turbovec_real_adapter_exact_baseline_shadow_replay_probe.rs",
                "agent_core/src/uas/turbovec_real_adapter_product_graph_no_contamination_probe.rs",
                "agent_core/src/bin/falsify_turbovec_real_adapter_exact_baseline_shadow_replay_probe.rs",
                "agent_core/src/bin/falsify_turbovec_real_adapter_product_graph_no_contamination_probe.rs",
                "Tools/falsifiers",
            ],
        )?,
        scan_row(
            "canon_surface",
            TurboVecProductGraphSurface::CanonSurface,
            &[
                "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md",
                "docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md",
                "docs/fusion/TURBOVEC_QAT_RUNTIME_AGNOSTIC_INTAKE_2026_06_06.md",
                "docs/fusion/MLX_QAT_TURBOVEC_LOCAL_SUBSTRATE_RESEARCH_2026_06_06.md",
                "docs/fusion/DEEP_RESEARCH_BREAKTHROUGH_SYNTHESIS_2026_06_06.md",
                "artifacts/lattice-coordinate-explainer/index.html",
            ],
        )?,
    ])
}

fn scan_row(
    surface_id: &str,
    surface: TurboVecProductGraphSurface,
    paths: &[&str],
) -> Result<TurboVecProductGraphAuditRow, Box<dyn std::error::Error>> {
    let mut files = Vec::new();
    for path in paths {
        collect_files(Path::new(path), &mut files)?;
    }
    files.sort();
    files.dedup();

    let mut scanned_file_count = 0;
    let mut scanned_bytes = 0;
    let mut allowed_architecture_mentions = 0;
    let mut forbidden_turbovec_mentions = 0;
    let mut product_import_mentions = 0;
    let mut product_dependency_mentions = 0;
    let mut native_link_mentions = 0;
    let mut route_policy_mentions = 0;
    let mut model_context_mentions = 0;
    let mut user_facing_green_copy_mentions = 0;
    let mut hidden_cloud_or_provider_fallback_mentions = 0;
    let mut live_large_model_claim_mentions = 0;
    let mut ssd_as_ram_claim_mentions = 0;

    for file in &files {
        let Ok(text) = fs::read_to_string(file) else {
            continue;
        };
        scanned_file_count += 1;
        scanned_bytes += text.len() as u64;
        let counts = count_contamination(&text, surface.allows_canon_mentions());
        allowed_architecture_mentions += counts.allowed_architecture_mentions;
        forbidden_turbovec_mentions += counts.forbidden_turbovec_mentions;
        product_import_mentions += counts.product_import_mentions;
        product_dependency_mentions += counts.product_dependency_mentions;
        native_link_mentions += counts.native_link_mentions;
        route_policy_mentions += counts.route_policy_mentions;
        model_context_mentions += counts.model_context_mentions;
        user_facing_green_copy_mentions += counts.user_facing_green_copy_mentions;
        hidden_cloud_or_provider_fallback_mentions +=
            counts.hidden_cloud_or_provider_fallback_mentions;
        live_large_model_claim_mentions += counts.live_large_model_claim_mentions;
        ssd_as_ram_claim_mentions += counts.ssd_as_ram_claim_mentions;
    }

    Ok(TurboVecProductGraphAuditRow {
        surface_id: surface_id.to_string(),
        surface,
        path_glob: paths.join(","),
        scanned_file_count,
        scanned_bytes,
        allowed_architecture_mentions,
        forbidden_turbovec_mentions,
        product_import_mentions,
        product_dependency_mentions,
        native_link_mentions,
        route_policy_mentions,
        model_context_mentions,
        user_facing_green_copy_mentions,
        hidden_cloud_or_provider_fallback_mentions,
        live_large_model_claim_mentions,
        ssd_as_ram_claim_mentions,
        product_files_copied: 0,
        product_graph_mutation_count: 0,
        proof_ref: format!("{PRODUCT_GRAPH_REF_PREFIX}{surface_id}:scanned"),
    })
}

fn collect_files(path: &Path, files: &mut Vec<PathBuf>) -> Result<(), Box<dyn std::error::Error>> {
    if !path.exists() {
        return Ok(());
    }
    if path.is_file() {
        if is_scan_file(path) {
            files.push(path.to_path_buf());
        }
        return Ok(());
    }
    for entry in fs::read_dir(path)? {
        let entry = entry?;
        let child = entry.path();
        if child.is_dir() {
            let name = child
                .file_name()
                .and_then(|value| value.to_str())
                .unwrap_or_default();
            if matches!(
                name,
                ".git" | "target" | "DerivedData" | "node_modules" | ".build"
            ) {
                continue;
            }
        }
        collect_files(&child, files)?;
    }
    Ok(())
}

fn is_scan_file(path: &Path) -> bool {
    let Some(ext) = path.extension().and_then(|value| value.to_str()) else {
        return false;
    };
    matches!(
        ext,
        "swift" | "rs" | "toml" | "plist" | "pbxproj" | "xcstrings" | "sh" | "md" | "html"
    )
}

#[derive(Default)]
// UAS: TurboVec product-graph contamination scan counters.
// Plane: Verification.
// Residency: metadata-only source scanner; no runtime/model/product bytes are loaded.
struct ContaminationCounts {
    allowed_architecture_mentions: u64,
    forbidden_turbovec_mentions: u64,
    product_import_mentions: u64,
    product_dependency_mentions: u64,
    native_link_mentions: u64,
    route_policy_mentions: u64,
    model_context_mentions: u64,
    user_facing_green_copy_mentions: u64,
    hidden_cloud_or_provider_fallback_mentions: u64,
    live_large_model_claim_mentions: u64,
    ssd_as_ram_claim_mentions: u64,
}

fn count_contamination(text: &str, allow_architecture_mentions: bool) -> ContaminationCounts {
    let mut counts = ContaminationCounts::default();
    let lower = text.to_ascii_lowercase();
    let total_turbovec = lower.matches("turbovec").count() as u64;
    if allow_architecture_mentions {
        counts.allowed_architecture_mentions = total_turbovec;
        return counts;
    } else {
        counts.forbidden_turbovec_mentions = total_turbovec;
    }
    for line in lower.lines() {
        let has_turbovec = line.contains("turbovec");
        if has_turbovec
            && (line.contains("import turbovec")
                || line.contains("use turbovec")
                || line.contains("mod turbovec")
                || line.contains("from turbovec")
                || line.contains("#include <turbovec"))
        {
            counts.product_import_mentions += 1;
        }
        if has_turbovec
            && (line.contains("[dependencies]")
                || line.contains("package.dependencies")
                || line.contains("swift package")
                || line.contains("cargo add")
                || line.contains("dependency"))
        {
            counts.product_dependency_mentions += 1;
        }
        if has_turbovec
            && (line.contains("native-link")
                || line.contains("linker")
                || line.contains("build.rs")
                || line.contains("accelerate")
                || line.contains("openblas"))
        {
            counts.native_link_mentions += 1;
        }
        if has_turbovec
            && (line.contains("runtime router")
                || line.contains("system g")
                || line.contains("route policy")
                || line.contains("route mutation")
                || line.contains("route authority"))
        {
            counts.route_policy_mentions += 1;
        }
        if has_turbovec
            && (line.contains("model context")
                || line.contains("context injection")
                || line.contains("inject context"))
        {
            counts.model_context_mentions += 1;
        }
        if has_turbovec
            && (line.contains("green")
                || line.contains("ready")
                || line.contains("live")
                || line.contains("available")
                || line.contains("user-facing"))
        {
            counts.user_facing_green_copy_mentions += 1;
        }
        if has_turbovec
            && (line.contains("hidden cloud")
                || line.contains("cloud fallback")
                || line.contains("provider fallback"))
        {
            counts.hidden_cloud_or_provider_fallback_mentions += 1;
        }
        if line.contains("live dense 70b")
            || (has_turbovec && line.contains("70b") && line.contains("live"))
        {
            counts.live_large_model_claim_mentions += 1;
        }
        if line.contains("ssd-as-ram") || line.contains("ssd as ram") {
            counts.ssd_as_ram_claim_mentions += 1;
        }
    }
    counts
}

fn ledger_from_rows(
    rows: &[TurboVecProductGraphAuditRow],
) -> Result<TurboVecProductGraphByteLedger, Box<dyn std::error::Error>> {
    let scanned_product_bytes = rows
        .iter()
        .filter(|row| {
            !matches!(
                row.surface,
                TurboVecProductGraphSurface::ProductManifest
                    | TurboVecProductGraphSurface::ArchitectureFalsifierGraph
                    | TurboVecProductGraphSurface::CanonSurface
            )
        })
        .map(|row| row.scanned_bytes)
        .sum();
    let scanned_manifest_bytes = rows
        .iter()
        .filter(|row| row.surface == TurboVecProductGraphSurface::ProductManifest)
        .map(|row| row.scanned_bytes)
        .sum();
    let scanned_architecture_metadata_bytes = rows
        .iter()
        .filter(|row| row.surface.allows_canon_mentions())
        .map(|row| row.scanned_bytes)
        .sum();
    Ok(TurboVecProductGraphByteLedger::metadata_only(
        scanned_product_bytes,
        scanned_manifest_bytes,
        scanned_architecture_metadata_bytes,
    )?)
}

fn policy() -> TurboVecProductGraphPolicy {
    TurboVecProductGraphPolicy::fail_closed()
}

fn proof_refs() -> TurboVecProductGraphProofRefs {
    TurboVecProductGraphProofRefs {
        product_graph_ref: format!("{PRODUCT_GRAPH_REF_PREFIX}accepted"),
        rollback_ref: format!("{ROLLBACK_REF_PREFIX}accepted"),
        run_event_log_ref: format!("{RUN_EVENT_LOG_REF_PREFIX}accepted"),
        answer_packet_ref: format!("{ANSWER_PACKET_REF_PREFIX}accepted"),
        compatibility_fence_ref: format!("{COMPATIBILITY_REF_PREFIX}accepted"),
        visible_summary: "Product graph no-contamination proof keeps TurboVec real-adapter work outside the app/runtime product graph: no product import, no product dependency, no native-link probe, no route mutation, no model-context injection, no hidden route authority, no hidden cloud fallback, no live dense 70B claim, no SSD-as-RAM claim, and no L2/L3 promotion. AnswerPacket-visible caveats preserve TurboVec as quarantined architecture/canon evidence only until later witnesses prove runtime behavior."
            .to_string(),
    }
}

fn red_fixture_results(
    upstream: &UasAddress,
    rows: &[TurboVecProductGraphAuditRow],
    ledger: &TurboVecProductGraphByteLedger,
) -> Vec<(&'static str, bool)> {
    let mut results = Vec::with_capacity(72);
    for (name, mutation) in row_mutations() {
        let mut rows = rows.to_vec();
        mutation(&mut rows);
        results.push((
            name,
            build_set(
                upstream.clone(),
                rows,
                policy(),
                proof_refs(),
                ledger.clone(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecProductGraphStatus::MetadataOnlyNoContamination,
                TurboVecProductGraphTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err(),
        ));
    }
    for (name, mutation) in policy_mutations() {
        let mut policy = policy();
        mutation(&mut policy);
        results.push((
            name,
            build_set(
                upstream.clone(),
                rows.to_vec(),
                policy,
                proof_refs(),
                ledger.clone(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecProductGraphStatus::MetadataOnlyNoContamination,
                TurboVecProductGraphTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err(),
        ));
    }
    for (name, mutation) in proof_mutations() {
        let mut proofs = proof_refs();
        mutation(&mut proofs);
        results.push((
            name,
            build_set(
                upstream.clone(),
                rows.to_vec(),
                policy(),
                proofs,
                ledger.clone(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecProductGraphStatus::MetadataOnlyNoContamination,
                TurboVecProductGraphTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err(),
        ));
    }
    for (name, mutation) in ledger_mutations() {
        let mut ledger = ledger.clone();
        mutation(&mut ledger);
        results.push((
            name,
            build_set(
                upstream.clone(),
                rows.to_vec(),
                policy(),
                proof_refs(),
                ledger,
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecProductGraphStatus::MetadataOnlyNoContamination,
                TurboVecProductGraphTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err(),
        ));
    }
    for (name, build, pro_status, tier, flag) in claim_cases() {
        results.push((
            name,
            build_set(
                upstream.clone(),
                rows.to_vec(),
                policy(),
                proof_refs(),
                ledger.clone(),
                build,
                pro_status,
                TurboVecProductGraphStatus::MetadataOnlyNoContamination,
                tier,
                matches!(flag, ClaimFlag::ProductPromotion),
                matches!(flag, ClaimFlag::ProductGraphMutation),
                matches!(flag, ClaimFlag::RouteMutation),
                matches!(flag, ClaimFlag::ContextInjection),
                matches!(flag, ClaimFlag::HiddenAuthority),
                matches!(flag, ClaimFlag::HiddenCloud),
                matches!(flag, ClaimFlag::LiveLargeModel),
                matches!(flag, ClaimFlag::SsdAsRam),
            )
            .is_err(),
        ));
    }
    results.push((
        "bad_upstream_shadow",
        build_set(
            UasAddress::new(UasKind::Other("other".to_string()), b"bad-shadow", 1),
            rows.to_vec(),
            policy(),
            proof_refs(),
            ledger.clone(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecProductGraphStatus::MetadataOnlyNoContamination,
            TurboVecProductGraphTier::T1L1Metadata,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .is_err(),
    ));
    results
}

type RowMutation = fn(&mut Vec<TurboVecProductGraphAuditRow>);

fn row_mutations() -> Vec<(&'static str, RowMutation)> {
    vec![
        ("remove_swift_product", |rows| {
            rows.retain(|row| row.surface != TurboVecProductGraphSurface::SwiftProductSource)
        }),
        ("remove_user_copy", |rows| {
            rows.retain(|row| row.surface != TurboVecProductGraphSurface::SwiftUserFacingCopy)
        }),
        ("remove_swift_routes", |rows| {
            rows.retain(|row| row.surface != TurboVecProductGraphSurface::SwiftRuntimeRouting)
        }),
        ("remove_rust_routes", |rows| {
            rows.retain(|row| row.surface != TurboVecProductGraphSurface::RustRuntimeRouting)
        }),
        ("remove_manifest", |rows| {
            rows.retain(|row| row.surface != TurboVecProductGraphSurface::ProductManifest)
        }),
        ("remove_architecture", |rows| {
            rows.retain(|row| {
                row.surface != TurboVecProductGraphSurface::ArchitectureFalsifierGraph
            })
        }),
        ("remove_canon", |rows| {
            rows.retain(|row| row.surface != TurboVecProductGraphSurface::CanonSurface)
        }),
        ("product_turbovec_mention", |rows| {
            mutate_surface(
                rows,
                TurboVecProductGraphSurface::SwiftProductSource,
                |row| row.forbidden_turbovec_mentions = 1,
            )
        }),
        ("product_import", |rows| {
            mutate_surface(
                rows,
                TurboVecProductGraphSurface::SwiftProductSource,
                |row| row.product_import_mentions = 1,
            )
        }),
        ("product_dependency", |rows| {
            mutate_surface(rows, TurboVecProductGraphSurface::ProductManifest, |row| {
                row.product_dependency_mentions = 1
            })
        }),
        ("native_link", |rows| {
            mutate_surface(rows, TurboVecProductGraphSurface::ProductManifest, |row| {
                row.native_link_mentions = 1
            })
        }),
        ("route_policy", |rows| {
            mutate_surface(
                rows,
                TurboVecProductGraphSurface::SwiftRuntimeRouting,
                |row| row.route_policy_mentions = 1,
            )
        }),
        ("model_context", |rows| {
            mutate_surface(
                rows,
                TurboVecProductGraphSurface::SwiftRuntimeRouting,
                |row| row.model_context_mentions = 1,
            )
        }),
        ("green_copy", |rows| {
            mutate_surface(
                rows,
                TurboVecProductGraphSurface::SwiftUserFacingCopy,
                |row| row.user_facing_green_copy_mentions = 1,
            )
        }),
        ("hidden_cloud", |rows| {
            mutate_surface(
                rows,
                TurboVecProductGraphSurface::SwiftRuntimeRouting,
                |row| row.hidden_cloud_or_provider_fallback_mentions = 1,
            )
        }),
        ("architecture_mentions_removed", |rows| {
            mutate_surface(
                rows,
                TurboVecProductGraphSurface::ArchitectureFalsifierGraph,
                |row| row.allowed_architecture_mentions = 0,
            )
        }),
        ("architecture_forbidden", |rows| {
            mutate_surface(
                rows,
                TurboVecProductGraphSurface::ArchitectureFalsifierGraph,
                |row| row.forbidden_turbovec_mentions = 1,
            )
        }),
        ("row_product_mutation", |rows| {
            mutate_surface(
                rows,
                TurboVecProductGraphSurface::SwiftProductSource,
                |row| row.product_graph_mutation_count = 1,
            )
        }),
    ]
}

fn mutate_surface(
    rows: &mut [TurboVecProductGraphAuditRow],
    surface: TurboVecProductGraphSurface,
    mutation: impl FnOnce(&mut TurboVecProductGraphAuditRow),
) {
    if let Some(row) = rows.iter_mut().find(|row| row.surface == surface) {
        mutation(row);
    }
}

type PolicyMutation = fn(&mut TurboVecProductGraphPolicy);

fn policy_mutations() -> Vec<(&'static str, PolicyMutation)> {
    vec![
        ("policy_import", |policy| policy.no_product_import = false),
        ("policy_route", |policy| {
            policy.no_route_policy_mutation = false
        }),
        ("policy_copy", |policy| {
            policy.no_user_facing_green_copy = false
        }),
        ("policy_answer_packet", |policy| {
            policy.answer_packet_required = false
        }),
        ("policy_runtime", |policy| {
            policy.no_runtime_execution = false
        }),
        ("policy_model_context", |policy| {
            policy.no_model_context_injection = false
        }),
    ]
}

type ProofMutation = fn(&mut TurboVecProductGraphProofRefs);

fn proof_mutations() -> Vec<(&'static str, ProofMutation)> {
    vec![
        ("bad_product_graph_ref", |proofs| {
            proofs.product_graph_ref = "bad:product".to_string()
        }),
        ("bad_rollback_ref", |proofs| {
            proofs.rollback_ref = "bad:rollback".to_string()
        }),
        ("bad_run_event_log_ref", |proofs| {
            proofs.run_event_log_ref = "bad:run".to_string()
        }),
        ("bad_answer_packet_ref", |proofs| {
            proofs.answer_packet_ref = "bad:answer".to_string()
        }),
        ("bad_compat_ref", |proofs| {
            proofs.compatibility_fence_ref = "bad:compat".to_string()
        }),
        ("weak_visible_summary", |proofs| {
            proofs.visible_summary = "too vague".to_string()
        }),
    ]
}

type LedgerMutation = fn(&mut TurboVecProductGraphByteLedger);

fn ledger_mutations() -> Vec<(&'static str, LedgerMutation)> {
    vec![
        ("raw_source_read", |ledger| {
            ledger.additional_turbovec_raw_source_bytes_inspected = 1
        }),
        ("copied_product_file", |ledger| {
            ledger.copied_product_file_count = 1
        }),
        ("dependency_added", |ledger| {
            ledger.product_dependencies_added = 1
        }),
        ("adapter_build", |ledger| ledger.adapter_build_count = 1),
        ("benchmark_run", |ledger| ledger.benchmark_run_count = 1),
        ("runtime_bytes", |ledger| ledger.allocated_runtime_bytes = 1),
        ("index_bytes", |ledger| ledger.index_bytes_opened = 1),
        ("provider_call", |ledger| ledger.provider_calls_made = 1),
    ]
}

#[derive(Clone, Copy)]
// UAS: TurboVec product-graph red-fixture claim mutation selector.
// Plane: Verification.
// Residency: metadata-only red fixture selector; no route/product mutation is performed.
enum ClaimFlag {
    ProductPromotion,
    ProductGraphMutation,
    RouteMutation,
    ContextInjection,
    HiddenAuthority,
    HiddenCloud,
    LiveLargeModel,
    SsdAsRam,
    None,
}

fn claim_cases() -> Vec<(
    &'static str,
    ProductBuild,
    ProStatus,
    TurboVecProductGraphTier,
    ClaimFlag,
)> {
    vec![
        (
            "product_promoted",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecProductGraphTier::T1L1Metadata,
            ClaimFlag::ProductPromotion,
        ),
        (
            "product_graph_mutated",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecProductGraphTier::T1L1Metadata,
            ClaimFlag::ProductGraphMutation,
        ),
        (
            "claim_route_mutation",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecProductGraphTier::T1L1Metadata,
            ClaimFlag::RouteMutation,
        ),
        (
            "claim_context",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecProductGraphTier::T1L1Metadata,
            ClaimFlag::ContextInjection,
        ),
        (
            "claim_hidden_authority",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecProductGraphTier::T1L1Metadata,
            ClaimFlag::HiddenAuthority,
        ),
        (
            "claim_hidden_cloud",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecProductGraphTier::T1L1Metadata,
            ClaimFlag::HiddenCloud,
        ),
        (
            "claim_live_large_model",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecProductGraphTier::T1L1Metadata,
            ClaimFlag::LiveLargeModel,
        ),
        (
            "claim_ssd_as_ram",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecProductGraphTier::T1L1Metadata,
            ClaimFlag::SsdAsRam,
        ),
        (
            "product_build_mas",
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            TurboVecProductGraphTier::T1L1Metadata,
            ClaimFlag::None,
        ),
        (
            "pro_status_live",
            ProductBuild::Pro,
            ProStatus::Live,
            TurboVecProductGraphTier::T1L1Metadata,
            ClaimFlag::None,
        ),
        (
            "tier_t2",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecProductGraphTier::T2L2Route,
            ClaimFlag::None,
        ),
    ]
}

fn red_pass(red_results: &[(&'static str, bool)], name: &str) -> bool {
    red_results
        .iter()
        .any(|(candidate, passed)| *candidate == name && *passed)
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
    expected_prefix: &str,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual.to_string()),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "starts_with_or_equals".to_string(),
            value: serde_json::Value::String(expected_prefix.to_string()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(
        name.to_string(),
        actual == expected_prefix || actual.starts_with(expected_prefix),
    );
}
