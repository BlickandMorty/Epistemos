//! `falsify_turbovec_real_adapter_dependency_envelope_probe`
//!
//! Metadata-only witness for `F-TurboVec-RealAdapterDependencyEnvelopeProbe`.
//! It binds the pinned TurboVec upstream manifest/dependency envelope without
//! fetching, cloning, importing, building, routing, or loading repository,
//! index, model, runtime, or provider bytes.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, TurboVecDependencyClass, TurboVecDependencyEnvelopeAction,
    TurboVecDependencyEnvelopeByteLedger, TurboVecDependencyEnvelopePolicy,
    TurboVecDependencyEnvelopeProofRefs, TurboVecDependencyEnvelopeStatus,
    TurboVecDependencyEnvelopeTier, TurboVecDependencyManifest, TurboVecDependencyRecord,
    TurboVecIndexOrgan, TurboVecManifestKind, TurboVecRealAdapterDependencyEnvelopeProbeSet,
    UasAddress, TURBOVEC_REAL_ADAPTER_DEPENDENCY_ENVELOPE_CURSOR,
    TURBOVEC_REAL_ADAPTER_DEPENDENCY_ENVELOPE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RealAdapterDependencyEnvelopeProbe";
const FIXTURE_ID: &str = "turbovec_real_adapter_dependency_envelope_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_real_adapter_dependency_envelope_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_dependency_envelope_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_source_pin_probe/result.json";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const GITHUB_METADATA_BYTES: u64 = 146_000;
const RAW_MANIFEST_BYTES: u64 = 33_000;
const SET_METADATA_BYTES: u64 = 160_000;
const PLANNED_QUARANTINE_BYTES: u64 = 8 * 1024 * 1024;
const RED_FIXTURE_FLOOR: u64 = 60;

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
        "{FALSIFIER_ID}: overall_pass={} manifests={} dependencies={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["manifest_count"].value,
        artifact.measurements["dependency_record_count"].value,
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
    let upstream = upstream_source_pin_address()?;
    let manifests = accepted_manifests();
    let dependencies = accepted_dependencies();
    let set = build_set(
        upstream.clone(),
        manifests.clone(),
        dependencies.clone(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecDependencyEnvelopeStatus::MetadataOnly,
        TurboVecDependencyEnvelopeTier::T1L1Metadata,
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
        manifests.iter().cloned().rev().collect(),
        dependencies.iter().cloned().rev().collect(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecDependencyEnvelopeStatus::MetadataOnly,
        TurboVecDependencyEnvelopeTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&upstream, &manifests, &dependencies)?;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_source_pin_bound",
            set.upstream_source_pin_witness_ref
                == "artifact:turbovec_real_adapter_source_pin_probe:result"
                && set
                    .upstream_source_pin_address
                    .to_string()
                    .starts_with("turbovec_real_adapter_source_pin_probe:")
                && red_pass(&red_results, "bad_upstream_cursor"),
        ),
        (
            "manifest_sha_coverage",
            metrics.manifest_count == 8
                && metrics.unique_manifest_sha_count == 8
                && red_pass(&red_results, "missing_root_cargo_toml")
                && red_pass(&red_results, "missing_rust_core_cargo_toml")
                && red_pass(&red_results, "missing_rust_build_rs")
                && red_pass(&red_results, "missing_python_cargo_toml")
                && red_pass(&red_results, "missing_python_pyproject_toml")
                && red_pass(&red_results, "missing_cargo_config_toml")
                && red_pass(&red_results, "missing_cargo_lock")
                && red_pass(&red_results, "missing_downstream_smoke_cargo_toml")
                && red_pass(&red_results, "bad_manifest_sha")
                && red_pass(&red_results, "duplicate_manifest")
                && red_pass(&red_results, "manifest_not_required")
                && red_pass(&red_results, "bad_manifest_ref_prefix"),
        ),
        (
            "workspace_envelope_bound",
            manifest_present(&set, "root_cargo_toml")
                && manifest_present(&set, "cargo_lock")
                && manifest_present(&set, "cargo_config_toml")
                && manifest_present(&set, "downstream_smoke_cargo_toml"),
        ),
        (
            "rust_core_dependency_envelope",
            metrics.rust_core_dependency_count == 8
                && red_pass(&red_results, "missing_rust_ndarray")
                && red_pass(&red_results, "missing_rust_rayon")
                && red_pass(&red_results, "missing_rust_ordered_float")
                && red_pass(&red_results, "missing_rust_rand")
                && red_pass(&red_results, "missing_rust_rand_chacha")
                && red_pass(&red_results, "missing_rust_rand_distr")
                && red_pass(&red_results, "missing_rust_statrs")
                && red_pass(&red_results, "missing_rust_faer"),
        ),
        (
            "target_specific_native_link_envelope",
            metrics.target_specific_dependency_count == 2
                && metrics.native_link_count == 2
                && red_pass(&red_results, "missing_target_macos_ndarray_blas")
                && red_pass(&red_results, "missing_target_linux_ndarray_blas")
                && red_pass(&red_results, "missing_native_macos_accelerate")
                && red_pass(&red_results, "missing_native_linux_openblas")
                && red_pass(&red_results, "native_bad_risk_prefix"),
        ),
        (
            "python_binding_envelope",
            metrics.python_boundary_count == 4
                && red_pass(&red_results, "missing_python_pyo3")
                && red_pass(&red_results, "missing_python_numpy_crate")
                && red_pass(&red_results, "missing_python_maturin")
                && red_pass(&red_results, "missing_python_numpy_runtime"),
        ),
        (
            "optional_integrations_denied_by_default",
            metrics.optional_python_integration_count == 4
                && set
                    .dependencies
                    .iter()
                    .filter(|dep| dep.class == TurboVecDependencyClass::PythonOptionalIntegration)
                    .all(|dep| {
                        dep.optional
                            && matches!(
                                dep.allowed_action,
                                TurboVecDependencyEnvelopeAction::MetadataOnly
                            )
                    })
                && red_pass(&red_results, "missing_python_langchain_optional")
                && red_pass(&red_results, "missing_python_llama_index_optional")
                && red_pass(&red_results, "missing_python_haystack_optional")
                && red_pass(&red_results, "missing_python_agno_optional")
                && red_pass(&red_results, "optional_marked_required")
                && red_pass(&red_results, "dependency_product_action"),
        ),
        (
            "downstream_smoke_visible",
            metrics.downstream_smoke_count == 1
                && red_pass(&red_results, "missing_downstream_smoke_path_dep"),
        ),
        (
            "cargo_lock_and_codegen_config_bound",
            manifest_present(&set, "cargo_lock")
                && manifest_present(&set, "cargo_config_toml")
                && dependency_present(&set, "x86_64_v3_rustflags")
                && red_pass(&red_results, "missing_x86_64_v3_rustflags"),
        ),
        (
            "proof_surfaces_required",
            red_pass(&red_results, "bad_source_pin_ref")
                && red_pass(&red_results, "bad_dependency_manifest_ref")
                && red_pass(&red_results, "bad_native_link_ref")
                && red_pass(&red_results, "bad_quarantine_path_ref")
                && red_pass(&red_results, "bad_provenance_ref")
                && red_pass(&red_results, "bad_rollback_ref")
                && red_pass(&red_results, "bad_run_event_log_ref")
                && red_pass(&red_results, "bad_answer_packet_ref")
                && red_pass(&red_results, "bad_compatibility_ref")
                && red_pass(&red_results, "bad_benchmark_caveat_ref")
                && red_pass(&red_results, "short_visible_summary"),
        ),
        (
            "metadata_manifest_bytes_only",
            metrics.raw_manifest_bytes_read == RAW_MANIFEST_BYTES
                && set.metadata_bytes_read == SET_METADATA_BYTES
                && metrics.fetched_repo_bytes == 0
                && metrics.cloned_repo_bytes == 0
                && metrics.copied_product_file_count == 0
                && metrics.product_dependency_count == 0
                && metrics.imported_external_crate_count == 0
                && metrics.built_external_binary_count == 0
                && metrics.native_link_probe_count == 0
                && metrics.opened_product_index_bytes == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_model_bytes_loaded == 0
                && metrics.provider_calls_made == 0,
        ),
        (
            "no_product_dependency_or_source_import",
            red_pass(&red_results, "fetched_repo_bytes")
                && red_pass(&red_results, "cloned_repo_bytes")
                && red_pass(&red_results, "copied_product_file")
                && red_pass(&red_results, "product_dependency_added")
                && red_pass(&red_results, "imported_external_crate")
                && red_pass(&red_results, "built_external_binary")
                && red_pass(&red_results, "native_link_probe")
                && red_pass(&red_results, "opened_product_index")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_model_bytes_loaded")
                && red_pass(&red_results, "provider_call"),
        ),
        (
            "no_route_context_or_hidden_authority",
            metrics.route_mutation_count == 0
                && metrics.model_context_injection_count == 0
                && metrics.hidden_authority_count == 0
                && red_pass(&red_results, "route_mutation")
                && red_pass(&red_results, "context_injection")
                && red_pass(&red_results, "hidden_authority")
                && red_pass(&red_results, "hidden_cloud"),
        ),
        (
            "product_and_large_model_claims_rejected",
            red_pass(&red_results, "product_promoted")
                && red_pass(&red_results, "product_build_mas")
                && red_pass(&red_results, "pro_status_live")
                && red_pass(&red_results, "status_runtime_approved")
                && red_pass(&red_results, "tier_t2")
                && red_pass(&red_results, "live_large_model")
                && red_pass(&red_results, "ssd_as_ram"),
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
        (
            "manifest_count",
            metrics.manifest_count,
            8,
            "==",
            "manifests",
        ),
        (
            "dependency_record_count",
            metrics.dependency_record_count,
            22,
            "==",
            "dependencies",
        ),
        (
            "rust_core_dependency_count",
            metrics.rust_core_dependency_count,
            8,
            "==",
            "dependencies",
        ),
        (
            "native_link_count",
            metrics.native_link_count,
            2,
            "==",
            "links",
        ),
        (
            "optional_python_integration_count",
            metrics.optional_python_integration_count,
            4,
            "==",
            "integrations",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            RED_FIXTURE_FLOOR,
            ">=",
            "fixtures",
        ),
        (
            "planned_quarantine_bytes",
            metrics.planned_quarantine_bytes,
            PLANNED_QUARANTINE_BYTES,
            "==",
            "bytes",
        ),
        (
            "raw_manifest_bytes_read",
            metrics.raw_manifest_bytes_read,
            RAW_MANIFEST_BYTES,
            "==",
            "bytes",
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
        "dependency_envelope_address",
        &set.set_address.to_string(),
        "turbovec_real_adapter_dependency_envelope_probe:",
        "uas_address",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        TURBOVEC_REAL_ADAPTER_DEPENDENCY_ENVELOPE_NEXT_CURSOR,
        TURBOVEC_REAL_ADAPTER_DEPENDENCY_ENVELOPE_NEXT_CURSOR,
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
            "kind": "metadata_only_dependency_envelope_scope",
            "detail": "Pinned TurboVec manifest and dependency metadata only. No repository bytes fetched or cloned, no product dependency added, no source imported, no adapter built, no native link probe run, no index/model/runtime/provider bytes loaded, and no route/context authority granted."
        })],
        notes: "Builds F-TurboVec-RealAdapterDependencyEnvelopeProbe as a T1/L1 metadata-only dependency envelope for the large-local-model compression track. It binds the pinned TurboVec revision to exact workspace, Rust core, native-link, Python binding, optional integration, Cargo.lock, codegen, and downstream-smoke manifests while keeping TurboVec in quarantine-reference form for Eidos/AppColdStore. This is research-to-build architecture proof only; it does not promote L2 product capability, L3 user surface, live dense 70B, SSD-as-RAM, hidden cloud, hidden PatternBoost, or hidden route authority.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_source_pin_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec source-pin gate has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_REAL_ADAPTER_DEPENDENCY_ENVELOPE_CURSOR)
    {
        return Err("upstream source-pin gate does not point at dependency envelope".into());
    }
    for axis in [
        "/pass_per_axis/metadata_only_source_pin",
        "/pass_per_axis/external_and_product_bytes_zero",
        "/pass_per_axis/no_route_context_or_hidden_authority",
        "/pass_per_axis/product_and_large_model_claims_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(format!("upstream source-pin axis missing or false: {axis}").into());
        }
    }
    let address = value
        .pointer("/measurements/source_pin_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("upstream source-pin address missing")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream: UasAddress,
    manifests: Vec<TurboVecDependencyManifest>,
    dependencies: Vec<TurboVecDependencyRecord>,
    proof_refs: TurboVecDependencyEnvelopeProofRefs,
    byte_ledger: TurboVecDependencyEnvelopeByteLedger,
    product_build: ProductBuild,
    pro_status: ProStatus,
    status: TurboVecDependencyEnvelopeStatus,
    promotion_tier: TurboVecDependencyEnvelopeTier,
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<TurboVecRealAdapterDependencyEnvelopeProbeSet, Box<dyn std::error::Error>> {
    Ok(TurboVecRealAdapterDependencyEnvelopeProbeSet::from_parts(
        upstream,
        manifests,
        dependencies,
        proof_refs,
        byte_ledger,
        product_build,
        pro_status,
        status,
        promotion_tier,
        organs(),
        TurboVecDependencyEnvelopePolicy::fail_closed(),
        SET_METADATA_BYTES,
        product_capability_promoted,
        route_mutation_allowed,
        model_context_injected,
        hidden_route_authority,
        hidden_cloud_fallback_allowed,
        live_large_model_claimed,
        ssd_as_ram_claimed,
    )?)
}

fn accepted_manifests() -> Vec<TurboVecDependencyManifest> {
    vec![
        manifest(
            "root_cargo_toml",
            TurboVecManifestKind::RootWorkspaceCargo,
            "Cargo.toml",
            "9bf15f9f5eba2de42db231e9235c4181f620277f",
            366,
        ),
        manifest(
            "rust_core_cargo_toml",
            TurboVecManifestKind::RustCoreCargo,
            "turbovec/Cargo.toml",
            "b48103b6c8b826501d13cfde926d9e9d3f118953",
            1003,
        ),
        manifest(
            "rust_build_rs",
            TurboVecManifestKind::RustBuildScript,
            "turbovec/build.rs",
            "7695df94659cbdacbf2915956c18e29bea9a917d",
            917,
        ),
        manifest(
            "python_cargo_toml",
            TurboVecManifestKind::PythonCargo,
            "turbovec-python/Cargo.toml",
            "9cc4a980cfb37e6aaec85c30c8d36f1cdd5919b2",
            314,
        ),
        manifest(
            "python_pyproject_toml",
            TurboVecManifestKind::PythonPyProject,
            "turbovec-python/pyproject.toml",
            "166cd434a337d3d861649b0aa7471b8920cec99c",
            1684,
        ),
        manifest(
            "cargo_config_toml",
            TurboVecManifestKind::CargoConfig,
            ".cargo/config.toml",
            "530c5b457b211df82dcab3d6a8751c33b514f1ba",
            980,
        ),
        manifest(
            "cargo_lock",
            TurboVecManifestKind::CargoLock,
            "Cargo.lock",
            "54548a61cb58347074bbbd78537439d75ab24a69",
            30_548,
        ),
        manifest(
            "downstream_smoke_cargo_toml",
            TurboVecManifestKind::DownstreamSmokeCargo,
            "examples/downstream-smoke/Cargo.toml",
            "76ada77fc7c563a952d090e9e5d4302444eecb7a",
            522,
        ),
    ]
}

fn manifest(
    id: &str,
    kind: TurboVecManifestKind,
    path: &str,
    sha: &str,
    size_bytes: u64,
) -> TurboVecDependencyManifest {
    TurboVecDependencyManifest {
        manifest_id: id.to_string(),
        kind,
        path: path.to_string(),
        sha: sha.to_string(),
        size_bytes,
        manifest_ref: format!("github_manifest:turbovec:{path}:{sha}"),
        required: true,
    }
}

fn accepted_dependencies() -> Vec<TurboVecDependencyRecord> {
    vec![
        dep(
            "rust_ndarray",
            TurboVecDependencyClass::RustCoreCrate,
            "ndarray",
            "0.17",
            "rust_core_cargo_toml",
            "all",
            false,
        ),
        dep(
            "rust_rayon",
            TurboVecDependencyClass::RustCoreCrate,
            "rayon",
            "1.10",
            "rust_core_cargo_toml",
            "all",
            false,
        ),
        dep(
            "rust_ordered_float",
            TurboVecDependencyClass::RustCoreCrate,
            "ordered-float",
            "4",
            "rust_core_cargo_toml",
            "all",
            false,
        ),
        dep(
            "rust_rand",
            TurboVecDependencyClass::RustCoreCrate,
            "rand",
            "0.8",
            "rust_core_cargo_toml",
            "all",
            false,
        ),
        dep(
            "rust_rand_chacha",
            TurboVecDependencyClass::RustCoreCrate,
            "rand_chacha",
            "0.3",
            "rust_core_cargo_toml",
            "all",
            false,
        ),
        dep(
            "rust_rand_distr",
            TurboVecDependencyClass::RustCoreCrate,
            "rand_distr",
            "0.4",
            "rust_core_cargo_toml",
            "all",
            false,
        ),
        dep(
            "rust_statrs",
            TurboVecDependencyClass::RustCoreCrate,
            "statrs",
            "0.17",
            "rust_core_cargo_toml",
            "all",
            false,
        ),
        dep(
            "rust_faer",
            TurboVecDependencyClass::RustCoreCrate,
            "faer",
            "0.20",
            "rust_core_cargo_toml",
            "all",
            false,
        ),
        dep(
            "target_macos_ndarray_blas",
            TurboVecDependencyClass::TargetSpecificRustCrate,
            "ndarray",
            "0.17+blas",
            "rust_core_cargo_toml",
            "macos",
            false,
        ),
        dep(
            "target_linux_ndarray_blas",
            TurboVecDependencyClass::TargetSpecificRustCrate,
            "ndarray",
            "0.17+blas",
            "rust_core_cargo_toml",
            "linux",
            false,
        ),
        dep(
            "native_macos_accelerate",
            TurboVecDependencyClass::NativeLink,
            "Accelerate.framework",
            "system",
            "rust_build_rs",
            "macos",
            false,
        ),
        dep(
            "native_linux_openblas",
            TurboVecDependencyClass::NativeLink,
            "openblas",
            "system",
            "rust_build_rs",
            "linux",
            false,
        ),
        dep(
            "python_pyo3",
            TurboVecDependencyClass::PythonBindingCrate,
            "pyo3",
            "0.27.0+extension-module+abi3-py39",
            "python_cargo_toml",
            "python",
            false,
        ),
        dep(
            "python_numpy_crate",
            TurboVecDependencyClass::PythonBindingCrate,
            "numpy",
            "0.27.0",
            "python_cargo_toml",
            "python",
            false,
        ),
        dep(
            "python_maturin",
            TurboVecDependencyClass::PythonBuildBackend,
            "maturin",
            ">=1.12,<2.0",
            "python_pyproject_toml",
            "python",
            false,
        ),
        dep(
            "python_numpy_runtime",
            TurboVecDependencyClass::PythonRuntimePackage,
            "numpy",
            ">=1.20",
            "python_pyproject_toml",
            "python",
            false,
        ),
        dep(
            "python_langchain_optional",
            TurboVecDependencyClass::PythonOptionalIntegration,
            "langchain-core",
            ">=0.3",
            "python_pyproject_toml",
            "python-extra",
            true,
        ),
        dep(
            "python_llama_index_optional",
            TurboVecDependencyClass::PythonOptionalIntegration,
            "llama-index-core",
            ">=0.11",
            "python_pyproject_toml",
            "python-extra",
            true,
        ),
        dep(
            "python_haystack_optional",
            TurboVecDependencyClass::PythonOptionalIntegration,
            "haystack-ai",
            ">=2.0",
            "python_pyproject_toml",
            "python-extra",
            true,
        ),
        dep(
            "python_agno_optional",
            TurboVecDependencyClass::PythonOptionalIntegration,
            "agno",
            ">=2.0",
            "python_pyproject_toml",
            "python-extra",
            true,
        ),
        dep(
            "downstream_smoke_path_dep",
            TurboVecDependencyClass::DownstreamSmokePath,
            "turbovec",
            "../../turbovec",
            "downstream_smoke_cargo_toml",
            "downstream-smoke",
            false,
        ),
        dep(
            "x86_64_v3_rustflags",
            TurboVecDependencyClass::CodegenConfig,
            "rustflags",
            "target-cpu=x86-64-v3",
            "cargo_config_toml",
            "x86_64",
            false,
        ),
    ]
}

fn dep(
    id: &str,
    // UAS-EXEMPT: helper parameter materializes TurboVecDependencyRecord::class.
    class: TurboVecDependencyClass,
    package: &str,
    version: &str,
    manifest_id: &str,
    target_scope: &str,
    optional: bool,
) -> TurboVecDependencyRecord {
    let risk_prefix = if class == TurboVecDependencyClass::NativeLink {
        "native_link:turbovec-envelope:"
    } else {
        "dependency_manifest:turbovec-envelope:"
    };
    let feature_refs = match id {
        "target_macos_ndarray_blas" | "target_linux_ndarray_blas" => {
            vec!["feature:ndarray/blas".to_string()]
        }
        "python_pyo3" => vec![
            "feature:pyo3/extension-module".to_string(),
            "feature:pyo3/abi3-py39".to_string(),
        ],
        "x86_64_v3_rustflags" => vec!["rustflag:-C target-cpu=x86-64-v3".to_string()],
        _ => Vec::new(),
    };
    TurboVecDependencyRecord {
        dependency_id: id.to_string(),
        class,
        package_name: package.to_string(),
        version_req: version.to_string(),
        manifest_id: manifest_id.to_string(),
        target_scope: target_scope.to_string(),
        optional,
        feature_refs,
        risk_ref: format!("{risk_prefix}{id}"),
        allowed_action: TurboVecDependencyEnvelopeAction::MetadataOnly,
    }
}

fn proof_refs() -> TurboVecDependencyEnvelopeProofRefs {
    TurboVecDependencyEnvelopeProofRefs {
        source_pin_ref: format!("source_pin:pinned_metadata_only:{PINNED_REVISION}"),
        dependency_manifest_ref: "dependency_manifest:turbovec-envelope:metadata-only".to_string(),
        native_link_ref: "native_link:turbovec-envelope:accelerate-openblas-no-probe".to_string(),
        quarantine_path_ref: "quarantine_path:turbovec-envelope:pending-sandbox-layout".to_string(),
        provenance_ref: "provenance:turbovec-envelope:clean-room-source-card".to_string(),
        rollback_ref: "rollback:turbovec-envelope:drop-dependency-card".to_string(),
        run_event_log_ref: "run_event_log:turbovec-envelope:metadata-only".to_string(),
        answer_packet_ref: "answer_packet:turbovec-envelope:visible-non-promotion".to_string(),
        compatibility_fence_ref: "compat:turbovec-envelope:no-product-deps".to_string(),
        benchmark_caveat_ref: "benchmark_caveat:turbovec-envelope:no-upstream-laundering"
            .to_string(),
        visible_summary: "TurboVec dependency metadata is envelope-planned only: Rust core deps, target-specific BLAS behavior, Python/maturin/numpy bindings, optional Python integrations, Cargo.lock, x86 config, and downstream smoke-test shape are recorded without fetching, cloning, adding dependencies, importing code, building adapters, opening indexes, loading model bytes, or mutating routes.".to_string(),
    }
}

fn byte_ledger() -> TurboVecDependencyEnvelopeByteLedger {
    TurboVecDependencyEnvelopeByteLedger::metadata_only(
        GITHUB_METADATA_BYTES,
        RAW_MANIFEST_BYTES,
        PLANNED_QUARANTINE_BYTES,
    )
}

fn red_fixture_results(
    upstream: &UasAddress,
    manifests: &[TurboVecDependencyManifest],
    dependencies: &[TurboVecDependencyRecord],
) -> Result<Vec<(String, bool)>, Box<dyn std::error::Error>> {
    let mut results = Vec::new();

    let wrong_upstream = UasAddress::from_str(
        "turbovec_real_adapter_owner_approval_probe:f092b3702f95b0cd98b2c1c5711c7b96ebca7bcd0bd456f7a2bd6dd3971753b3@1779040800000",
    )?;
    results.push((
        "bad_upstream_cursor".to_string(),
        set_with_parts(wrong_upstream, manifests.to_vec(), dependencies.to_vec()).is_err(),
    ));

    for id in [
        "root_cargo_toml",
        "rust_core_cargo_toml",
        "rust_build_rs",
        "python_cargo_toml",
        "python_pyproject_toml",
        "cargo_config_toml",
        "cargo_lock",
        "downstream_smoke_cargo_toml",
    ] {
        let mut bad = manifests.to_vec();
        bad.retain(|manifest| manifest.manifest_id != id);
        results.push((
            format!("missing_{id}"),
            set_with_parts(upstream.clone(), bad, dependencies.to_vec()).is_err(),
        ));
    }

    let mut bad = manifests.to_vec();
    bad[0].sha = "short".to_string();
    results.push((
        "bad_manifest_sha".to_string(),
        set_with_parts(upstream.clone(), bad, dependencies.to_vec()).is_err(),
    ));

    let mut bad = manifests.to_vec();
    bad.push(bad[0].clone());
    results.push((
        "duplicate_manifest".to_string(),
        set_with_parts(upstream.clone(), bad, dependencies.to_vec()).is_err(),
    ));

    let mut bad = manifests.to_vec();
    bad[0].required = false;
    results.push((
        "manifest_not_required".to_string(),
        set_with_parts(upstream.clone(), bad, dependencies.to_vec()).is_err(),
    ));

    let mut bad = manifests.to_vec();
    bad[0].manifest_ref = "github_content:turbovec:Cargo.toml".to_string();
    results.push((
        "bad_manifest_ref_prefix".to_string(),
        set_with_parts(upstream.clone(), bad, dependencies.to_vec()).is_err(),
    ));

    for id in [
        "rust_ndarray",
        "rust_rayon",
        "rust_ordered_float",
        "rust_rand",
        "rust_rand_chacha",
        "rust_rand_distr",
        "rust_statrs",
        "rust_faer",
        "target_macos_ndarray_blas",
        "target_linux_ndarray_blas",
        "native_macos_accelerate",
        "native_linux_openblas",
        "python_pyo3",
        "python_numpy_crate",
        "python_maturin",
        "python_numpy_runtime",
        "python_langchain_optional",
        "python_llama_index_optional",
        "python_haystack_optional",
        "python_agno_optional",
        "downstream_smoke_path_dep",
        "x86_64_v3_rustflags",
    ] {
        let mut bad = dependencies.to_vec();
        bad.retain(|dep| dep.dependency_id != id);
        results.push((
            format!("missing_{id}"),
            set_with_parts(upstream.clone(), manifests.to_vec(), bad).is_err(),
        ));
    }

    let mut bad = dependencies.to_vec();
    bad[0].manifest_id = "missing_manifest".to_string();
    results.push((
        "unknown_dependency_manifest".to_string(),
        set_with_parts(upstream.clone(), manifests.to_vec(), bad).is_err(),
    ));

    let mut bad = dependencies.to_vec();
    bad.push(bad[0].clone());
    results.push((
        "duplicate_dependency".to_string(),
        set_with_parts(upstream.clone(), manifests.to_vec(), bad).is_err(),
    ));

    let mut bad = dependencies.to_vec();
    bad[0].risk_ref = "native_link:turbovec-envelope:wrong-class".to_string();
    results.push((
        "bad_dependency_risk_prefix".to_string(),
        set_with_parts(upstream.clone(), manifests.to_vec(), bad).is_err(),
    ));

    let mut bad = dependencies.to_vec();
    if let Some(dep) = bad
        .iter_mut()
        .find(|dep| dep.dependency_id == "native_macos_accelerate")
    {
        dep.risk_ref = "dependency_manifest:turbovec-envelope:native".to_string();
    }
    results.push((
        "native_bad_risk_prefix".to_string(),
        set_with_parts(upstream.clone(), manifests.to_vec(), bad).is_err(),
    ));

    let mut bad = dependencies.to_vec();
    bad[0].target_scope.clear();
    results.push((
        "empty_target_scope".to_string(),
        set_with_parts(upstream.clone(), manifests.to_vec(), bad).is_err(),
    ));

    let mut bad = dependencies.to_vec();
    if let Some(dep) = bad
        .iter_mut()
        .find(|dep| dep.dependency_id == "python_langchain_optional")
    {
        dep.optional = false;
    }
    results.push((
        "optional_marked_required".to_string(),
        set_with_parts(upstream.clone(), manifests.to_vec(), bad).is_err(),
    ));

    let mut bad = dependencies.to_vec();
    bad[0].optional = true;
    results.push((
        "required_marked_optional".to_string(),
        set_with_parts(upstream.clone(), manifests.to_vec(), bad).is_err(),
    ));

    let mut bad = dependencies.to_vec();
    bad[0].allowed_action = TurboVecDependencyEnvelopeAction::AddProductDependency;
    results.push((
        "dependency_product_action".to_string(),
        set_with_parts(upstream.clone(), manifests.to_vec(), bad).is_err(),
    ));

    for name in [
        "bad_source_pin_ref",
        "bad_dependency_manifest_ref",
        "bad_native_link_ref",
        "bad_quarantine_path_ref",
        "bad_provenance_ref",
        "bad_rollback_ref",
        "bad_run_event_log_ref",
        "bad_answer_packet_ref",
        "bad_compatibility_ref",
        "bad_benchmark_caveat_ref",
    ] {
        let mut refs = proof_refs();
        match name {
            "bad_source_pin_ref" => refs.source_pin_ref = "source:unbound".to_string(),
            "bad_dependency_manifest_ref" => {
                refs.dependency_manifest_ref = "manifest:unbound".to_string()
            }
            "bad_native_link_ref" => refs.native_link_ref = "link:unbound".to_string(),
            "bad_quarantine_path_ref" => {
                refs.quarantine_path_ref = "quarantine:unbound".to_string()
            }
            "bad_provenance_ref" => refs.provenance_ref = "provenance:unbound".to_string(),
            "bad_rollback_ref" => refs.rollback_ref = "rollback:unbound".to_string(),
            "bad_run_event_log_ref" => refs.run_event_log_ref = "log:unbound".to_string(),
            "bad_answer_packet_ref" => refs.answer_packet_ref = "answer:unbound".to_string(),
            "bad_compatibility_ref" => refs.compatibility_fence_ref = "compat:unbound".to_string(),
            "bad_benchmark_caveat_ref" => {
                refs.benchmark_caveat_ref = "benchmark:unbound".to_string()
            }
            _ => unreachable!("all proof ref fixtures are listed explicitly"),
        }
        results.push((
            name.to_string(),
            set_with_refs(
                upstream.clone(),
                manifests.to_vec(),
                dependencies.to_vec(),
                refs,
            )
            .is_err(),
        ));
    }

    let mut refs = proof_refs();
    refs.visible_summary = "short".to_string();
    results.push((
        "short_visible_summary".to_string(),
        set_with_refs(
            upstream.clone(),
            manifests.to_vec(),
            dependencies.to_vec(),
            refs,
        )
        .is_err(),
    ));

    for name in [
        "fetched_repo_bytes",
        "cloned_repo_bytes",
        "copied_product_file",
        "product_dependency_added",
        "imported_external_crate",
        "built_external_binary",
        "native_link_probe",
        "opened_product_index",
        "model_bytes_loaded",
        "runtime_model_bytes_loaded",
        "provider_call",
    ] {
        let mut ledger = byte_ledger();
        match name {
            "fetched_repo_bytes" => ledger.fetched_repo_bytes = 1,
            "cloned_repo_bytes" => ledger.cloned_repo_bytes = 1,
            "copied_product_file" => ledger.copied_product_file_count = 1,
            "product_dependency_added" => ledger.product_dependency_count = 1,
            "imported_external_crate" => ledger.imported_external_crate_count = 1,
            "built_external_binary" => ledger.built_external_binary_count = 1,
            "native_link_probe" => ledger.native_link_probe_count = 1,
            "opened_product_index" => ledger.opened_product_index_bytes = 1,
            "model_bytes_loaded" => ledger.model_bytes_loaded = 1,
            "runtime_model_bytes_loaded" => ledger.runtime_model_bytes_loaded = 1,
            "provider_call" => ledger.provider_calls_made = 1,
            _ => unreachable!("all byte-ledger fixtures are listed explicitly"),
        }
        results.push((
            name.to_string(),
            set_with_ledger(
                upstream.clone(),
                manifests.to_vec(),
                dependencies.to_vec(),
                ledger,
            )
            .is_err(),
        ));
    }

    for (name, product_promoted, route, context, hidden, cloud, live_large, ssd_ram) in [
        (
            "product_promoted",
            true,
            false,
            false,
            false,
            false,
            false,
            false,
        ),
        (
            "route_mutation",
            false,
            true,
            false,
            false,
            false,
            false,
            false,
        ),
        (
            "context_injection",
            false,
            false,
            true,
            false,
            false,
            false,
            false,
        ),
        (
            "hidden_authority",
            false,
            false,
            false,
            true,
            false,
            false,
            false,
        ),
        (
            "hidden_cloud",
            false,
            false,
            false,
            false,
            true,
            false,
            false,
        ),
        (
            "live_large_model",
            false,
            false,
            false,
            false,
            false,
            true,
            false,
        ),
        ("ssd_as_ram", false, false, false, false, false, false, true),
    ] {
        results.push((
            name.to_string(),
            build_set(
                upstream.clone(),
                manifests.to_vec(),
                dependencies.to_vec(),
                proof_refs(),
                byte_ledger(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecDependencyEnvelopeStatus::MetadataOnly,
                TurboVecDependencyEnvelopeTier::T1L1Metadata,
                product_promoted,
                route,
                context,
                hidden,
                cloud,
                live_large,
                ssd_ram,
            )
            .is_err(),
        ));
    }

    for (name, build, pro_status, status, tier) in [
        (
            "product_build_mas",
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            TurboVecDependencyEnvelopeStatus::MetadataOnly,
            TurboVecDependencyEnvelopeTier::T1L1Metadata,
        ),
        (
            "pro_status_live",
            ProductBuild::Pro,
            ProStatus::Live,
            TurboVecDependencyEnvelopeStatus::MetadataOnly,
            TurboVecDependencyEnvelopeTier::T1L1Metadata,
        ),
        (
            "status_runtime_approved",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecDependencyEnvelopeStatus::RuntimeApprovedByLaterWitness,
            TurboVecDependencyEnvelopeTier::T1L1Metadata,
        ),
        (
            "tier_t2",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecDependencyEnvelopeStatus::MetadataOnly,
            TurboVecDependencyEnvelopeTier::T2L2Route,
        ),
    ] {
        results.push((
            name.to_string(),
            build_set(
                upstream.clone(),
                manifests.to_vec(),
                dependencies.to_vec(),
                proof_refs(),
                byte_ledger(),
                build,
                pro_status,
                status,
                tier,
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

    Ok(results)
}

fn set_with_parts(
    upstream: UasAddress,
    manifests: Vec<TurboVecDependencyManifest>,
    dependencies: Vec<TurboVecDependencyRecord>,
) -> Result<TurboVecRealAdapterDependencyEnvelopeProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        manifests,
        dependencies,
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecDependencyEnvelopeStatus::MetadataOnly,
        TurboVecDependencyEnvelopeTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn set_with_refs(
    upstream: UasAddress,
    manifests: Vec<TurboVecDependencyManifest>,
    dependencies: Vec<TurboVecDependencyRecord>,
    refs: TurboVecDependencyEnvelopeProofRefs,
) -> Result<TurboVecRealAdapterDependencyEnvelopeProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        manifests,
        dependencies,
        refs,
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecDependencyEnvelopeStatus::MetadataOnly,
        TurboVecDependencyEnvelopeTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn set_with_ledger(
    upstream: UasAddress,
    manifests: Vec<TurboVecDependencyManifest>,
    dependencies: Vec<TurboVecDependencyRecord>,
    ledger: TurboVecDependencyEnvelopeByteLedger,
) -> Result<TurboVecRealAdapterDependencyEnvelopeProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        manifests,
        dependencies,
        proof_refs(),
        ledger,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecDependencyEnvelopeStatus::MetadataOnly,
        TurboVecDependencyEnvelopeTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn organs() -> Vec<TurboVecIndexOrgan> {
    vec![
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ]
}

fn manifest_present(set: &TurboVecRealAdapterDependencyEnvelopeProbeSet, id: &str) -> bool {
    set.manifests
        .iter()
        .any(|manifest| manifest.manifest_id == id)
}

fn dependency_present(set: &TurboVecRealAdapterDependencyEnvelopeProbeSet, id: &str) -> bool {
    set.dependencies
        .iter()
        .any(|dependency| dependency.dependency_id == id)
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
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(actual),
            unit: unit.to_string(),
        },
    );
    let operator = if name == "dependency_envelope_address" {
        "starts_with"
    } else {
        "=="
    };
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::json!(expected),
            unit: unit.to_string(),
        },
    );
    let pass = if name == "dependency_envelope_address" {
        actual.starts_with(expected)
    } else {
        actual == expected
    };
    pass_per_axis.insert(name.to_string(), pass);
}
