//! `falsify_turbovec_real_adapter_native_link_absence_preflight_probe`
//!
//! Metadata-only witness for
//! `F-TurboVec-RealAdapterNativeLinkAbsencePreflightProbe`. It consumes the
//! product-graph no-contamination witness and proves the next TurboVec/QAT
//! research-to-build step still performs zero native-link probes, adapter
//! builds, product dependency insertions, runtime/model loads, route mutation,
//! or user-facing promotion.

use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, TurboVecNativeLinkAction, TurboVecNativeLinkPreflightByteLedger,
    TurboVecNativeLinkPreflightPolicy, TurboVecNativeLinkPreflightProofRefs,
    TurboVecNativeLinkPreflightRow, TurboVecNativeLinkPreflightStatus,
    TurboVecNativeLinkPreflightTier, TurboVecNativeLinkSurface,
    TurboVecRealAdapterNativeLinkAbsencePreflightProbeSet, UasAddress, UasKind,
    TURBOVEC_REAL_ADAPTER_NATIVE_LINK_ABSENCE_PREFLIGHT_CURSOR,
    TURBOVEC_REAL_ADAPTER_NATIVE_LINK_ABSENCE_PREFLIGHT_NEXT_CURSOR,
    TURBOVEC_REAL_ADAPTER_PRODUCT_GRAPH_NO_CONTAMINATION_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RealAdapterNativeLinkAbsencePreflightProbe";
const FIXTURE_ID: &str = "turbovec_real_adapter_native_link_absence_preflight_probe_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_turbovec_real_adapter_native_link_absence_preflight_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_native_link_absence_preflight_probe/result.json";
const UPSTREAM_PRODUCT_GRAPH_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_product_graph_no_contamination_probe/result.json";
const DEPENDENCY_ENVELOPE_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_dependency_envelope_probe/result.json";
const SOURCE_MANIFEST_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_source_byte_manifest_probe/result.json";
const SOURCE_INSPECTION_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_source_inspection_policy_probe/result.json";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const RED_FIXTURE_FLOOR: u64 = 44;

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
    let upstream = upstream_product_graph_address()?;
    let rows = native_link_rows();
    let ledger = byte_ledger()?;
    let set = build_set(
        upstream.clone(),
        rows.clone(),
        policy(),
        proof_refs(),
        ledger.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecNativeLinkPreflightStatus::MetadataOnlyNoNativeLink,
        TurboVecNativeLinkPreflightTier::T1L1Metadata,
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
        ledger,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecNativeLinkPreflightStatus::MetadataOnlyNoNativeLink,
        TurboVecNativeLinkPreflightTier::T1L1Metadata,
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
            "upstream_product_graph_bound",
            set.upstream_product_graph_witness_ref
                == "artifact:turbovec_real_adapter_product_graph_no_contamination_probe:result"
                && set
                    .upstream_product_graph_address
                    .to_string()
                    .starts_with("turbovec_real_adapter_product_graph_no_contamination_probe:")
                && red_pass(&red_results, "bad_upstream_product_graph"),
        ),
        (
            "dependency_envelope_and_manifest_refs",
            set.proof_refs
                .dependency_envelope_ref
                .starts_with("artifact:turbovec_real_adapter_dependency_envelope_probe:")
                && set
                    .proof_refs
                    .source_manifest_ref
                    .starts_with("artifact:turbovec_real_adapter_source_byte_manifest_probe:")
                && set
                    .proof_refs
                    .source_inspection_policy_ref
                    .starts_with("artifact:turbovec_real_adapter_source_inspection_policy_probe:")
                && red_pass(&red_results, "bad_dependency_ref")
                && red_pass(&red_results, "bad_source_manifest_ref")
                && red_pass(&red_results, "bad_source_inspection_ref"),
        ),
        (
            "native_link_surfaces_blocked",
            metrics.row_count >= 10
                && metrics.native_link_absent_row_count == metrics.row_count
                && metrics.owner_approval_required_count == metrics.row_count
                && metrics.target_specific_native_link_count >= 2
                && metrics.python_native_boundary_count >= 3
                && metrics.product_surface_preflight_count >= 2
                && red_pass(&red_results, "remove_target_blas")
                && red_pass(&red_results, "remove_python_boundary")
                && red_pass(&red_results, "remove_product_surface")
                && red_pass(&red_results, "allow_native_link")
                && red_pass(&red_results, "owner_approval_not_required"),
        ),
        (
            "no_native_link_execution_bytes",
            metrics.build_script_exec_count == 0
                && metrics.cargo_build_invocation_count == 0
                && metrics.linker_invocation_count == 0
                && metrics.dynamic_library_load_count == 0
                && metrics.python_build_invocation_count == 0
                && metrics.row_build_script_exec_count == 0
                && metrics.row_cargo_build_invocation_count == 0
                && metrics.row_linker_invocation_count == 0
                && metrics.row_dynamic_library_load_count == 0
                && metrics.row_python_build_invocation_count == 0
                && red_pass(&red_results, "ledger_build_script")
                && red_pass(&red_results, "ledger_cargo_build")
                && red_pass(&red_results, "ledger_linker")
                && red_pass(&red_results, "ledger_dylib")
                && red_pass(&red_results, "ledger_python_build")
                && red_pass(&red_results, "row_build_script")
                && red_pass(&red_results, "row_linker")
                && red_pass(&red_results, "row_dylib")
                && red_pass(&red_results, "row_python_build"),
        ),
        (
            "no_product_dependency_or_route_mutation",
            metrics.product_dependency_count == 0
                && metrics.copied_product_file_count == 0
                && metrics.environment_mutation_count == 0
                && metrics.benchmark_run_count == 0
                && metrics.row_product_dependency_count == 0
                && metrics.row_product_route_mutation_count == 0
                && metrics.row_environment_mutation_count == 0
                && metrics.row_benchmark_authority_claim_count == 0
                && red_pass(&red_results, "ledger_product_dep")
                && red_pass(&red_results, "ledger_product_copy")
                && red_pass(&red_results, "ledger_env_mutation")
                && red_pass(&red_results, "ledger_benchmark")
                && red_pass(&red_results, "row_product_dep")
                && red_pass(&red_results, "row_route_mutation")
                && red_pass(&red_results, "row_benchmark_authority"),
        ),
        (
            "proof_surfaces_required",
            set.proof_refs.product_graph_ref
                == "product_graph:turbovec-no-contamination:native-link-preflight"
                && set
                    .proof_refs
                    .native_link_absence_ref
                    .starts_with("native_link:turbovec-preflight:")
                && set
                    .proof_refs
                    .rollback_ref
                    .starts_with("rollback:turbovec-native-link:")
                && set
                    .proof_refs
                    .run_event_log_ref
                    .starts_with("run_event_log:turbovec-native-link:")
                && set
                    .proof_refs
                    .answer_packet_ref
                    .starts_with("answer_packet:turbovec-native-link:")
                && set
                    .proof_refs
                    .compatibility_fence_ref
                    .starts_with("compat:turbovec-native-link:")
                && set.proof_refs.visible_summary.contains("AnswerPacket")
                && red_pass(&red_results, "bad_native_link_absence_ref")
                && red_pass(&red_results, "bad_rollback_ref")
                && red_pass(&red_results, "bad_run_event_log_ref")
                && red_pass(&red_results, "bad_answer_packet_ref")
                && red_pass(&red_results, "bad_compat_ref")
                && red_pass(&red_results, "short_visible_summary"),
        ),
        (
            "product_and_large_model_claims_rejected",
            metrics.raw_turbovec_source_bytes_read == 0
                && metrics.fetched_repo_bytes == 0
                && metrics.cloned_repo_bytes == 0
                && metrics.index_bytes_opened == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.product_capability_promoted_count == 0
                && metrics.native_dry_run_approved_count == 0
                && metrics.route_mutation_count == 0
                && metrics.hidden_authority_count == 0
                && metrics.live_large_model_claim_count == 0
                && metrics.ssd_as_ram_claim_count == 0
                && red_pass(&red_results, "raw_source_read")
                && red_pass(&red_results, "fetch_repo")
                && red_pass(&red_results, "clone_repo")
                && red_pass(&red_results, "index_bytes")
                && red_pass(&red_results, "model_bytes")
                && red_pass(&red_results, "provider_call")
                && red_pass(&red_results, "product_promotion")
                && red_pass(&red_results, "native_dry_run_approved")
                && red_pass(&red_results, "route_mutation")
                && red_pass(&red_results, "hidden_authority")
                && red_pass(&red_results, "live_large_model")
                && red_pass(&red_results, "ssd_as_ram"),
        ),
        (
            "reversed_order_address_deterministic",
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

    for (name, actual, expected, operator, unit) in [
        ("row_count", metrics.row_count, 10, ">=", "count"),
        (
            "native_link_absent_row_count",
            metrics.native_link_absent_row_count,
            metrics.row_count,
            "==",
            "count",
        ),
        (
            "target_specific_native_link_count",
            metrics.target_specific_native_link_count,
            2,
            ">=",
            "count",
        ),
        (
            "python_native_boundary_count",
            metrics.python_native_boundary_count,
            3,
            ">=",
            "count",
        ),
        (
            "product_surface_preflight_count",
            metrics.product_surface_preflight_count,
            2,
            ">=",
            "count",
        ),
        (
            "build_script_exec_count",
            metrics.build_script_exec_count + metrics.row_build_script_exec_count,
            0,
            "==",
            "count",
        ),
        (
            "linker_invocation_count",
            metrics.linker_invocation_count + metrics.row_linker_invocation_count,
            0,
            "==",
            "count",
        ),
        (
            "dynamic_library_load_count",
            metrics.dynamic_library_load_count + metrics.row_dynamic_library_load_count,
            0,
            "==",
            "count",
        ),
        (
            "product_dependency_count",
            metrics.product_dependency_count + metrics.row_product_dependency_count,
            0,
            "==",
            "count",
        ),
        (
            "model_bytes_loaded",
            metrics.model_bytes_loaded + metrics.runtime_model_bytes_loaded,
            0,
            "==",
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
        "native_link_absence_preflight_address",
        &set.set_address.to_string(),
        "turbovec_real_adapter_native_link_absence_preflight_probe:",
        "uas_address",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        TURBOVEC_REAL_ADAPTER_NATIVE_LINK_ABSENCE_PREFLIGHT_NEXT_CURSOR,
        TURBOVEC_REAL_ADAPTER_NATIVE_LINK_ABSENCE_PREFLIGHT_NEXT_CURSOR,
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
            "kind": "metadata_native_link_absence_scope",
            "detail": "Native-link absence preflight only. No TurboVec clone, raw-source read, Cargo build, build.rs execution, linker invocation, dynamic-library load, Python extension build, benchmark run, product dependency insertion, route mutation, model/runtime/provider bytes, or L2/L3 promotion."
        })],
        notes: "Builds F-TurboVec-RealAdapterNativeLinkAbsencePreflightProbe as a T1/L1 metadata preflight after product-graph no-contamination. It enumerates native-link/build-script risk surfaces and keeps the next dry run owner-approved, visible, rollback-bound, and AnswerPacket-disclosed.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_product_graph_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = fs::read_to_string(UPSTREAM_PRODUCT_GRAPH_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream product-graph no-contamination witness has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_REAL_ADAPTER_NATIVE_LINK_ABSENCE_PREFLIGHT_CURSOR)
        || TURBOVEC_REAL_ADAPTER_PRODUCT_GRAPH_NO_CONTAMINATION_NEXT_CURSOR
            != TURBOVEC_REAL_ADAPTER_NATIVE_LINK_ABSENCE_PREFLIGHT_CURSOR
    {
        return Err(
            "upstream product-graph witness does not point at native-link preflight".into(),
        );
    }
    for axis in [
        "/pass_per_axis/upstream_shadow_replay_bound",
        "/pass_per_axis/product_surface_scan_coverage",
        "/pass_per_axis/product_import_dependency_absence",
        "/pass_per_axis/route_context_copy_absence",
        "/pass_per_axis/byte_scope_no_runtime_or_product_mutation",
        "/pass_per_axis/product_and_large_model_claims_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(format!("upstream product-graph axis {axis} did not pass").into());
        }
    }
    let address = value
        .pointer("/measurements/product_graph_no_contamination_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing product_graph_no_contamination_address")?;
    Ok(UasAddress::from_str(address)?)
}

fn artifact_size(path: &str) -> Result<u64, Box<dyn std::error::Error>> {
    Ok(fs::metadata(path)?.len())
}

fn byte_ledger() -> Result<TurboVecNativeLinkPreflightByteLedger, Box<dyn std::error::Error>> {
    let product_graph_bytes = artifact_size(UPSTREAM_PRODUCT_GRAPH_RESULT)?;
    let dependency_bytes = artifact_size(DEPENDENCY_ENVELOPE_RESULT)?
        + artifact_size(SOURCE_MANIFEST_RESULT)?
        + artifact_size(SOURCE_INSPECTION_RESULT)?;
    Ok(TurboVecNativeLinkPreflightByteLedger::metadata_only(
        product_graph_bytes,
        dependency_bytes,
        64 * 1024,
    )?)
}

fn build_set(
    upstream: UasAddress,
    rows: Vec<TurboVecNativeLinkPreflightRow>,
    policy: TurboVecNativeLinkPreflightPolicy,
    proof_refs: TurboVecNativeLinkPreflightProofRefs,
    ledger: TurboVecNativeLinkPreflightByteLedger,
    product_build: ProductBuild,
    pro_status: ProStatus,
    status: TurboVecNativeLinkPreflightStatus,
    tier: TurboVecNativeLinkPreflightTier,
    product_capability_promoted: bool,
    native_dry_run_approved: bool,
    route_mutation_allowed: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<TurboVecRealAdapterNativeLinkAbsencePreflightProbeSet, Box<dyn std::error::Error>> {
    Ok(
        TurboVecRealAdapterNativeLinkAbsencePreflightProbeSet::from_parts(
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
            native_dry_run_approved,
            route_mutation_allowed,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        )?,
    )
}

fn native_link_rows() -> Vec<TurboVecNativeLinkPreflightRow> {
    vec![
        row(
            "rust_build_rs",
            TurboVecNativeLinkSurface::RustBuildScript,
            "rust-core/build.rs",
            TurboVecNativeLinkAction::DenyBuildScript,
            vec![
                "artifact:turbovec_real_adapter_dependency_envelope_probe:build-rs",
                "artifact:turbovec_real_adapter_source_byte_manifest_probe:rust-build-script-row",
            ],
        ),
        row(
            "macos_accelerate_blas",
            TurboVecNativeLinkSurface::TargetSpecificBlas,
            "target_os=macos",
            TurboVecNativeLinkAction::DenyNativeLink,
            vec![
                "artifact:turbovec_real_adapter_dependency_envelope_probe:target_macos_ndarray_blas",
                "artifact:turbovec_real_adapter_source_inspection_policy_probe:native-link-block",
            ],
        ),
        row(
            "linux_openblas_blas",
            TurboVecNativeLinkSurface::TargetSpecificBlas,
            "target_os=linux",
            TurboVecNativeLinkAction::DenyNativeLink,
            vec![
                "artifact:turbovec_real_adapter_dependency_envelope_probe:target_linux_ndarray_blas",
                "artifact:turbovec_real_adapter_source_inspection_policy_probe:native-link-block",
            ],
        ),
        row(
            "python_pyo3_extension",
            TurboVecNativeLinkSurface::PythonExtension,
            "python-extension",
            TurboVecNativeLinkAction::DenyDynamicLoad,
            vec![
                "artifact:turbovec_real_adapter_dependency_envelope_probe:python_pyo3",
                "artifact:turbovec_real_adapter_source_inspection_policy_probe:python-binding-boundary",
            ],
        ),
        row(
            "python_maturin_backend",
            TurboVecNativeLinkSurface::PythonBuildBackend,
            "python-build-backend",
            TurboVecNativeLinkAction::DenyNativeLink,
            vec![
                "artifact:turbovec_real_adapter_dependency_envelope_probe:python_maturin",
                "artifact:turbovec_real_adapter_source_byte_manifest_probe:pyproject-row",
            ],
        ),
        row(
            "python_numpy_runtime",
            TurboVecNativeLinkSurface::PythonRuntimePackage,
            "python-runtime-package",
            TurboVecNativeLinkAction::DenyDynamicLoad,
            vec![
                "artifact:turbovec_real_adapter_dependency_envelope_probe:python_numpy",
                "artifact:turbovec_real_adapter_source_inspection_policy_probe:python-runtime-boundary",
            ],
        ),
        row(
            "cargo_x86_64_v3_config",
            TurboVecNativeLinkSurface::CargoConfig,
            "x86_64-v3-rustflags",
            TurboVecNativeLinkAction::DenyBuildScript,
            vec![
                "artifact:turbovec_real_adapter_dependency_envelope_probe:x86_64_v3_rustflags",
                "artifact:turbovec_real_adapter_source_byte_manifest_probe:cargo-config-row",
            ],
        ),
        row(
            "downstream_smoke_path",
            TurboVecNativeLinkSurface::DownstreamSmoke,
            "downstream-smoke",
            TurboVecNativeLinkAction::DenyNativeLink,
            vec![
                "artifact:turbovec_real_adapter_dependency_envelope_probe:downstream_smoke_path_dep",
                "artifact:turbovec_real_adapter_source_byte_manifest_probe:downstream-smoke-row",
            ],
        ),
        row(
            "benchmark_native_runtime",
            TurboVecNativeLinkSurface::BenchmarkSurface,
            "benchmark-only",
            TurboVecNativeLinkAction::DenyNativeLink,
            vec![
                "artifact:turbovec_real_adapter_source_byte_manifest_probe:benchmark-rows",
                "artifact:turbovec_real_adapter_source_inspection_policy_probe:benchmark-non-authority",
            ],
        ),
        row(
            "product_manifest_dependency_absence",
            TurboVecNativeLinkSurface::ProductManifest,
            "Epistemos product manifests",
            TurboVecNativeLinkAction::DenyProductDependency,
            vec![
                "artifact:turbovec_real_adapter_product_graph_no_contamination_probe:product-manifest-scan",
                "artifact:turbovec_real_adapter_dependency_envelope_probe:no-product-deps",
            ],
        ),
        row(
            "product_route_context_absence",
            TurboVecNativeLinkSurface::ProductRouteSurface,
            "RuntimeRouter/SystemG/Eidos",
            TurboVecNativeLinkAction::DenyRouteMutation,
            vec![
                "artifact:turbovec_real_adapter_product_graph_no_contamination_probe:route-context-scan",
                "artifact:turbovec_real_adapter_dependency_envelope_probe:no-route-authority",
            ],
        ),
    ]
}

fn row(
    id: &str,
    surface: TurboVecNativeLinkSurface,
    target_scope: &str,
    allowed_action: TurboVecNativeLinkAction,
    source_refs: Vec<&str>,
) -> TurboVecNativeLinkPreflightRow {
    TurboVecNativeLinkPreflightRow {
        risk_id: id.to_string(),
        surface,
        target_scope: target_scope.to_string(),
        source_refs: source_refs.into_iter().map(str::to_string).collect(),
        native_link_ref: format!("native_link:turbovec-preflight:{id}"),
        product_graph_ref: format!("product_graph:turbovec-no-contamination:{id}"),
        allowed_action,
        owner_approval_required: true,
        native_link_absent: true,
        build_script_exec_count: 0,
        cargo_build_invocation_count: 0,
        linker_invocation_count: 0,
        dynamic_library_load_count: 0,
        python_build_invocation_count: 0,
        environment_mutation_count: 0,
        product_dependency_count: 0,
        product_route_mutation_count: 0,
        benchmark_authority_claim_count: 0,
    }
}

fn policy() -> TurboVecNativeLinkPreflightPolicy {
    TurboVecNativeLinkPreflightPolicy::fail_closed()
}

fn proof_refs() -> TurboVecNativeLinkPreflightProofRefs {
    TurboVecNativeLinkPreflightProofRefs {
        product_graph_ref: "product_graph:turbovec-no-contamination:native-link-preflight"
            .to_string(),
        dependency_envelope_ref: "artifact:turbovec_real_adapter_dependency_envelope_probe:result"
            .to_string(),
        source_manifest_ref: "artifact:turbovec_real_adapter_source_byte_manifest_probe:result"
            .to_string(),
        source_inspection_policy_ref:
            "artifact:turbovec_real_adapter_source_inspection_policy_probe:result".to_string(),
        native_link_absence_ref: "native_link:turbovec-preflight:no-link-no-load".to_string(),
        rollback_ref: "rollback:turbovec-native-link:drop-preflight-card".to_string(),
        run_event_log_ref: "run_event_log:turbovec-native-link:metadata-only".to_string(),
        answer_packet_ref: "answer_packet:turbovec-native-link:visible-non-promotion".to_string(),
        compatibility_fence_ref: "compat:turbovec-native-link:no-product-deps".to_string(),
        visible_summary: "TurboVec native-link preflight is no native-link metadata only: Rust build.rs, target-specific BLAS, PyO3/maturin/numpy, cargo config, downstream smoke tests, benchmark claims, product manifests, and route surfaces are blocked until owner-approved dry-run witnesses exist; AnswerPacket must show rollback, compatibility fence, and L2/L3 non-promotion.".to_string(),
    }
}

fn red_fixture_results(
    upstream: &UasAddress,
    rows: &[TurboVecNativeLinkPreflightRow],
    ledger: &TurboVecNativeLinkPreflightByteLedger,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();

    let wrong_upstream = UasAddress::new(
        UasKind::Other("other_product_graph".to_string()),
        b"bad-upstream",
        1,
    );
    results.push((
        "bad_upstream_product_graph".to_string(),
        build_set(
            wrong_upstream,
            rows.to_vec(),
            policy(),
            proof_refs(),
            ledger.clone(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeLinkPreflightStatus::MetadataOnlyNoNativeLink,
            TurboVecNativeLinkPreflightTier::T1L1Metadata,
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

    for (name, mutation) in row_mutations() {
        let mut bad_rows = rows.to_vec();
        mutation(&mut bad_rows);
        results.push((
            name.to_string(),
            build_set(
                upstream.clone(),
                bad_rows,
                policy(),
                proof_refs(),
                ledger.clone(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecNativeLinkPreflightStatus::MetadataOnlyNoNativeLink,
                TurboVecNativeLinkPreflightTier::T1L1Metadata,
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
        let mut bad_policy = policy();
        mutation(&mut bad_policy);
        results.push((
            name.to_string(),
            build_set(
                upstream.clone(),
                rows.to_vec(),
                bad_policy,
                proof_refs(),
                ledger.clone(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecNativeLinkPreflightStatus::MetadataOnlyNoNativeLink,
                TurboVecNativeLinkPreflightTier::T1L1Metadata,
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
        let mut bad_refs = proof_refs();
        mutation(&mut bad_refs);
        results.push((
            name.to_string(),
            build_set(
                upstream.clone(),
                rows.to_vec(),
                policy(),
                bad_refs,
                ledger.clone(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecNativeLinkPreflightStatus::MetadataOnlyNoNativeLink,
                TurboVecNativeLinkPreflightTier::T1L1Metadata,
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
        let mut bad_ledger = ledger.clone();
        mutation(&mut bad_ledger);
        results.push((
            name.to_string(),
            build_set(
                upstream.clone(),
                rows.to_vec(),
                policy(),
                proof_refs(),
                bad_ledger,
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecNativeLinkPreflightStatus::MetadataOnlyNoNativeLink,
                TurboVecNativeLinkPreflightTier::T1L1Metadata,
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

    for (name, build, status, tier, flag) in claim_cases() {
        results.push((
            name.to_string(),
            build_set(
                upstream.clone(),
                rows.to_vec(),
                policy(),
                proof_refs(),
                ledger.clone(),
                build,
                status,
                TurboVecNativeLinkPreflightStatus::MetadataOnlyNoNativeLink,
                tier,
                matches!(flag, ClaimFlag::ProductPromotion),
                matches!(flag, ClaimFlag::NativeDryRunApproved),
                matches!(flag, ClaimFlag::RouteMutation),
                matches!(flag, ClaimFlag::HiddenAuthority),
                matches!(flag, ClaimFlag::HiddenCloud),
                matches!(flag, ClaimFlag::LiveLargeModel),
                matches!(flag, ClaimFlag::SsdAsRam),
            )
            .is_err(),
        ));
    }

    results
}

type RowMutation = fn(&mut Vec<TurboVecNativeLinkPreflightRow>);

fn row_mutations() -> Vec<(&'static str, RowMutation)> {
    vec![
        ("remove_target_blas", |rows| {
            rows.retain(|row| row.surface != TurboVecNativeLinkSurface::TargetSpecificBlas)
        }),
        ("remove_python_boundary", |rows| {
            rows.retain(|row| row.surface != TurboVecNativeLinkSurface::PythonExtension)
        }),
        ("remove_product_surface", |rows| {
            rows.retain(|row| row.surface != TurboVecNativeLinkSurface::ProductManifest)
        }),
        ("allow_native_link", |rows| {
            mutate_row(rows, "macos_accelerate_blas", |row| {
                row.native_link_absent = false
            })
        }),
        ("owner_approval_not_required", |rows| {
            mutate_row(rows, "macos_accelerate_blas", |row| {
                row.owner_approval_required = false
            })
        }),
        ("row_build_script", |rows| {
            mutate_row(rows, "rust_build_rs", |row| row.build_script_exec_count = 1)
        }),
        ("row_linker", |rows| {
            mutate_row(rows, "macos_accelerate_blas", |row| {
                row.linker_invocation_count = 1
            })
        }),
        ("row_dylib", |rows| {
            mutate_row(rows, "python_pyo3_extension", |row| {
                row.dynamic_library_load_count = 1
            })
        }),
        ("row_python_build", |rows| {
            mutate_row(rows, "python_maturin_backend", |row| {
                row.python_build_invocation_count = 1
            })
        }),
        ("row_product_dep", |rows| {
            mutate_row(rows, "product_manifest_dependency_absence", |row| {
                row.product_dependency_count = 1
            })
        }),
        ("row_route_mutation", |rows| {
            mutate_row(rows, "product_route_context_absence", |row| {
                row.product_route_mutation_count = 1
            })
        }),
        ("row_benchmark_authority", |rows| {
            mutate_row(rows, "benchmark_native_runtime", |row| {
                row.benchmark_authority_claim_count = 1
            })
        }),
        ("bad_row_source_ref", |rows| {
            mutate_row(rows, "rust_build_rs", |row| {
                row.source_refs = vec!["raw-source:unbound".to_string()]
            })
        }),
        ("bad_row_native_ref", |rows| {
            mutate_row(rows, "rust_build_rs", |row| {
                row.native_link_ref = "link:unbound".to_string()
            })
        }),
    ]
}

fn mutate_row(
    rows: &mut [TurboVecNativeLinkPreflightRow],
    risk_id: &str,
    mutation: impl FnOnce(&mut TurboVecNativeLinkPreflightRow),
) {
    if let Some(row) = rows.iter_mut().find(|row| row.risk_id == risk_id) {
        mutation(row);
    }
}

type PolicyMutation = fn(&mut TurboVecNativeLinkPreflightPolicy);

fn policy_mutations() -> Vec<(&'static str, PolicyMutation)> {
    vec![
        ("policy_build_script", |policy| {
            policy.build_script_execution_denied = false
        }),
        ("policy_linker", |policy| {
            policy.linker_invocation_denied = false
        }),
        ("policy_dylib", |policy| {
            policy.dynamic_library_load_denied = false
        }),
        ("policy_python", |policy| {
            policy.python_extension_build_denied = false
        }),
        ("policy_product_dep", |policy| {
            policy.product_dependency_insertion_denied = false
        }),
        ("policy_route_mutation", |policy| {
            policy.product_route_mutation_denied = false
        }),
        ("policy_no_answer_packet", |policy| {
            policy.answer_packet_required = false
        }),
    ]
}

type ProofMutation = fn(&mut TurboVecNativeLinkPreflightProofRefs);

fn proof_mutations() -> Vec<(&'static str, ProofMutation)> {
    vec![
        ("bad_dependency_ref", |refs| {
            refs.dependency_envelope_ref = "bad:dependency".to_string()
        }),
        ("bad_source_manifest_ref", |refs| {
            refs.source_manifest_ref = "bad:manifest".to_string()
        }),
        ("bad_source_inspection_ref", |refs| {
            refs.source_inspection_policy_ref = "bad:policy".to_string()
        }),
        ("bad_native_link_absence_ref", |refs| {
            refs.native_link_absence_ref = "bad:native".to_string()
        }),
        ("bad_rollback_ref", |refs| {
            refs.rollback_ref = "bad:rollback".to_string()
        }),
        ("bad_run_event_log_ref", |refs| {
            refs.run_event_log_ref = "bad:log".to_string()
        }),
        ("bad_answer_packet_ref", |refs| {
            refs.answer_packet_ref = "bad:packet".to_string()
        }),
        ("bad_compat_ref", |refs| {
            refs.compatibility_fence_ref = "bad:compat".to_string()
        }),
        ("short_visible_summary", |refs| {
            refs.visible_summary = "short no native-link".to_string()
        }),
    ]
}

type LedgerMutation = fn(&mut TurboVecNativeLinkPreflightByteLedger);

fn ledger_mutations() -> Vec<(&'static str, LedgerMutation)> {
    vec![
        ("ledger_build_script", |ledger| {
            ledger.build_script_exec_count = 1
        }),
        ("ledger_cargo_build", |ledger| {
            ledger.cargo_build_invocation_count = 1
        }),
        ("ledger_linker", |ledger| ledger.linker_invocation_count = 1),
        ("ledger_dylib", |ledger| {
            ledger.dynamic_library_load_count = 1
        }),
        ("ledger_python_build", |ledger| {
            ledger.python_build_invocation_count = 1
        }),
        ("ledger_product_dep", |ledger| {
            ledger.product_dependency_count = 1
        }),
        ("ledger_product_copy", |ledger| {
            ledger.copied_product_file_count = 1
        }),
        ("ledger_env_mutation", |ledger| {
            ledger.environment_mutation_count = 1
        }),
        ("ledger_benchmark", |ledger| ledger.benchmark_run_count = 1),
        ("raw_source_read", |ledger| {
            ledger.raw_turbovec_source_bytes_read = 1
        }),
        ("fetch_repo", |ledger| ledger.fetched_repo_bytes = 1),
        ("clone_repo", |ledger| ledger.cloned_repo_bytes = 1),
        ("index_bytes", |ledger| ledger.index_bytes_opened = 1),
        ("model_bytes", |ledger| ledger.model_bytes_loaded = 1),
        ("provider_call", |ledger| ledger.provider_calls_made = 1),
    ]
}

#[derive(Clone, Copy)]
// UAS: TurboVec native-link preflight red-fixture claim mutation selector.
// Plane: Verification.
// Residency: metadata-only red fixture selector; no product mutation is performed.
enum ClaimFlag {
    ProductPromotion,
    NativeDryRunApproved,
    RouteMutation,
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
    TurboVecNativeLinkPreflightTier,
    ClaimFlag,
)> {
    vec![
        (
            "product_promotion",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeLinkPreflightTier::T1L1Metadata,
            ClaimFlag::ProductPromotion,
        ),
        (
            "native_dry_run_approved",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeLinkPreflightTier::T1L1Metadata,
            ClaimFlag::NativeDryRunApproved,
        ),
        (
            "route_mutation",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeLinkPreflightTier::T1L1Metadata,
            ClaimFlag::RouteMutation,
        ),
        (
            "hidden_authority",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeLinkPreflightTier::T1L1Metadata,
            ClaimFlag::HiddenAuthority,
        ),
        (
            "hidden_cloud",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeLinkPreflightTier::T1L1Metadata,
            ClaimFlag::HiddenCloud,
        ),
        (
            "live_large_model",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeLinkPreflightTier::T1L1Metadata,
            ClaimFlag::LiveLargeModel,
        ),
        (
            "ssd_as_ram",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeLinkPreflightTier::T1L1Metadata,
            ClaimFlag::SsdAsRam,
        ),
        (
            "bad_build_mas",
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            TurboVecNativeLinkPreflightTier::T1L1Metadata,
            ClaimFlag::None,
        ),
        (
            "bad_status_live",
            ProductBuild::Pro,
            ProStatus::Live,
            TurboVecNativeLinkPreflightTier::T1L1Metadata,
            ClaimFlag::None,
        ),
        (
            "bad_tier_t2",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeLinkPreflightTier::T2L2Route,
            ClaimFlag::None,
        ),
    ]
}

fn red_pass(results: &[(String, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| candidate == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
    expected: &str,
    unit: &str,
) {
    let pass = if name.ends_with("_address") {
        actual.starts_with(expected)
    } else {
        actual == expected
    };
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
            operator: if name.ends_with("_address") {
                "starts_with".to_string()
            } else {
                "==".to_string()
            },
            value: serde_json::Value::String(expected.to_string()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}
