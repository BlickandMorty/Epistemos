//! `falsify_turbovec_real_adapter_source_byte_manifest_probe`
//!
//! Metadata-only witness for `F-TurboVec-RealAdapterSourceByteManifestProbe`.
//! It binds pinned TurboVec Git tree metadata after the fetch-lease gate while
//! forbidding source archive fetch, raw content read, source import, product
//! dependency insertion, adapter build, native-link probe, runtime/model/index
//! bytes, route/context mutation, hidden authority, and product promotion.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    source_byte_manifest_digest, ProStatus, ProductBuild, TurboVecIndexOrgan,
    TurboVecRealAdapterSourceByteManifestProbeSet, TurboVecSourceManifestByteLedger,
    TurboVecSourceManifestDisposition, TurboVecSourceManifestEntry, TurboVecSourceManifestKind,
    TurboVecSourceManifestPolicy, TurboVecSourceManifestProofRefs,
    TurboVecSourceManifestRootBucket, TurboVecSourceManifestSource, TurboVecSourceManifestStatus,
    TurboVecSourceManifestTier, UasAddress, TURBOVEC_REAL_ADAPTER_SOURCE_BYTE_MANIFEST_CURSOR,
    TURBOVEC_REAL_ADAPTER_SOURCE_BYTE_MANIFEST_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RealAdapterSourceByteManifestProbe";
const FIXTURE_ID: &str = "turbovec_real_adapter_source_byte_manifest_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_real_adapter_source_byte_manifest_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_source_byte_manifest_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_fetch_lease_probe/result.json";
const SOURCE_URL: &str = "https://github.com/RyanCodrai/turbovec";
const TREE_API_URL: &str =
    "https://api.github.com/repos/RyanCodrai/turbovec/git/trees/efe29a184986cbf562a9847c2ac52a2990bfaca2?recursive=1";
const CODELOAD_URL: &str =
    "https://codeload.github.com/RyanCodrai/turbovec/tar.gz/efe29a184986cbf562a9847c2ac52a2990bfaca2";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const QUARANTINE_ROOT: &str =
    ".epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2";
const TREE_METADATA_BYTES_READ: u64 = 128_000;
const EXPECTED_TREE_ENTRY_COUNT: u64 = 207;
const EXPECTED_BLOB_COUNT: u64 = 180;
const EXPECTED_TREE_NODE_COUNT: u64 = 27;
const EXPECTED_TOTAL_BLOB_BYTES: u64 = 1_615_603;
const RED_FIXTURE_FLOOR: u64 = 100;

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
        "{FALSIFIER_ID}: overall_pass={} entries={} roots={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_entry_count"].value,
        artifact.measurements["root_bucket_count"].value,
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
    let upstream = upstream_fetch_lease_address()?;
    let set = build_set(
        upstream.clone(),
        source(),
        entries(),
        buckets(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceManifestStatus::MetadataOnlyManifest,
        TurboVecSourceManifestTier::T1L1Metadata,
        TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
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
        source(),
        entries().into_iter().rev().collect(),
        buckets().into_iter().rev().collect(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceManifestStatus::MetadataOnlyManifest,
        TurboVecSourceManifestTier::T1L1Metadata,
        TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&upstream);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_fetch_lease_bound",
            set.upstream_fetch_lease_witness_ref
                == "artifact:turbovec_real_adapter_fetch_lease_probe:result"
                && set
                    .upstream_fetch_lease_address
                    .to_string()
                    .starts_with("turbovec_real_adapter_fetch_lease_probe:")
                && red_pass(&red_results, "bad_upstream_cursor"),
        ),
        (
            "source_tree_metadata_bound",
            set.source.source_url == SOURCE_URL
                && set.source.tree_api_url == TREE_API_URL
                && set.source.codeload_url == CODELOAD_URL
                && set.source.pinned_revision == PINNED_REVISION
                && set.source.current_head_revision == PINNED_REVISION
                && !set.source.tree_truncated
                && metrics.total_tree_entry_count == EXPECTED_TREE_ENTRY_COUNT
                && metrics.blob_count == EXPECTED_BLOB_COUNT
                && metrics.tree_node_count == EXPECTED_TREE_NODE_COUNT
                && metrics.total_blob_bytes == EXPECTED_TOTAL_BLOB_BYTES
                && red_pass(&red_results, "bad_source_ref")
                && red_pass(&red_results, "bad_tree_api_url")
                && red_pass(&red_results, "bad_codeload_url")
                && red_pass(&red_results, "bad_pinned_revision")
                && red_pass(&red_results, "bad_current_head")
                && red_pass(&red_results, "tree_truncated")
                && red_pass(&red_results, "tree_entry_count_drift")
                && red_pass(&red_results, "blob_count_drift")
                && red_pass(&red_results, "tree_node_count_drift")
                && red_pass(&red_results, "total_blob_bytes_drift"),
        ),
        (
            "required_manifest_entries_bound",
            metrics.required_entry_count == 22
                && red_pass(&red_results, "missing_LICENSE")
                && red_pass(&red_results, "missing_Cargo_toml")
                && red_pass(&red_results, "missing_turbovec_src_search_rs")
                && red_pass(&red_results, "missing_turbovec-python_pyproject_toml")
                && red_pass(&red_results, "duplicate_entry_path")
                && red_pass(&red_results, "bad_entry_sha")
                && red_pass(&red_results, "bad_entry_size")
                && red_pass(&red_results, "bad_entry_mode")
                && red_pass(&red_results, "zero_entry_size"),
        ),
        (
            "root_bucket_coverage_bound",
            metrics.root_bucket_count == 15
                && red_pass(&red_results, "missing_root_benchmarks")
                && red_pass(&red_results, "missing_root_turbovec")
                && red_pass(&red_results, "missing_root_turbovec-python")
                && red_pass(&red_results, "bad_root_count")
                && red_pass(&red_results, "duplicate_root_bucket")
                && red_pass(&red_results, "root_not_required"),
        ),
        (
            "path_and_product_root_policy_bound",
            red_pass(&red_results, "absolute_entry_path")
                && red_pass(&red_results, "traversal_entry_path")
                && red_pass(&red_results, "empty_entry_path")
                && red_pass(&red_results, "dot_entry_path")
                && red_pass(&red_results, "double_slash_entry_path")
                && red_pass(&red_results, "backslash_entry_path")
                && red_pass(&red_results, "product_path_agent_core")
                && red_pass(&red_results, "product_path_epistemos")
                && red_pass(&red_results, "product_path_graph_engine")
                && red_pass(&red_results, "product_path_tools")
                && red_pass(&red_results, "product_path_artifacts")
                && red_pass(&red_results, "product_path_target"),
        ),
        (
            "symlink_binary_benchmark_dispositions_bound",
            metrics.blocked_symlink_count >= 1
                && metrics.blocked_binary_asset_count >= 1
                && metrics.benchmark_claim_only_count >= 2
                && red_pass(&red_results, "symlink_not_blocked")
                && red_pass(&red_results, "binary_asset_import_allowed")
                && red_pass(&red_results, "benchmark_claim_authoritative")
                && red_pass(&red_results, "source_inspection_allowed_on_entry")
                && red_pass(&red_results, "native_link_allowed_on_entry"),
        ),
        (
            "manifest_policy_fail_closed",
            set.policy.github_tree_metadata_only
                && !set.policy.source_bytes_fetched
                && !set.policy.raw_content_read
                && !set.policy.codeload_archive_opened
                && !set.policy.local_quarantine_files_written
                && !set.policy.source_inspection_allowed_now
                && !set.policy.product_import_allowed
                && !set.policy.product_dependency_allowed
                && !set.policy.native_link_probe_allowed
                && !set.policy.runtime_execution_allowed
                && !set.policy.index_or_model_bytes_allowed
                && set.policy.symlink_targets_blocked
                && set.policy.binary_assets_blocked
                && set.policy.benchmark_claims_non_authoritative
                && set.policy.source_inspection_requires_later_witness
                && set.policy.cleanup_replay_required
                && set.policy.answer_packet_required
                && red_pass(&red_results, "policy_raw_content_read")
                && red_pass(&red_results, "policy_source_bytes_fetched")
                && red_pass(&red_results, "policy_codeload_opened")
                && red_pass(&red_results, "policy_quarantine_written")
                && red_pass(&red_results, "policy_source_inspection_allowed")
                && red_pass(&red_results, "policy_product_import")
                && red_pass(&red_results, "policy_dependency")
                && red_pass(&red_results, "policy_native_link")
                && red_pass(&red_results, "policy_runtime")
                && red_pass(&red_results, "policy_index_model")
                && red_pass(&red_results, "policy_symlink_not_blocked")
                && red_pass(&red_results, "policy_binary_not_blocked")
                && red_pass(&red_results, "policy_benchmark_authoritative")
                && red_pass(&red_results, "policy_later_witness_not_required")
                && red_pass(&red_results, "policy_cleanup_not_required")
                && red_pass(&red_results, "policy_answer_packet_not_required"),
        ),
        (
            "proof_surfaces_required",
            set.proof_refs.visible_summary.len() >= 360
                && red_pass(&red_results, "bad_fetch_lease_ref")
                && red_pass(&red_results, "bad_provenance_ref")
                && red_pass(&red_results, "bad_rollback_ref")
                && red_pass(&red_results, "bad_cleanup_ref")
                && red_pass(&red_results, "bad_no_product_graph_ref")
                && red_pass(&red_results, "bad_run_event_log_ref")
                && red_pass(&red_results, "bad_answer_packet_ref")
                && red_pass(&red_results, "bad_compatibility_ref")
                && red_pass(&red_results, "bad_native_link_ref")
                && red_pass(&red_results, "bad_benchmark_caveat_ref")
                && red_pass(&red_results, "short_visible_summary"),
        ),
        (
            "bytes_remain_metadata_only",
            metrics.git_tree_metadata_bytes_read == TREE_METADATA_BYTES_READ
                && metrics.raw_source_bytes_read == 0
                && metrics.source_archive_bytes_fetched == 0
                && metrics.local_quarantine_bytes_written == 0
                && metrics.product_dependency_count == 0
                && metrics.copied_product_file_count == 0
                && metrics.native_link_probe_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "metadata_bytes_zero")
                && red_pass(&red_results, "metadata_bytes_over")
                && red_pass(&red_results, "declared_blob_bytes_mismatch")
                && red_pass(&red_results, "raw_source_bytes_read")
                && red_pass(&red_results, "source_archive_bytes_fetched")
                && red_pass(&red_results, "local_quarantine_bytes_written")
                && red_pass(&red_results, "copied_product_file")
                && red_pass(&red_results, "product_dependency")
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
            !set.route_mutation_allowed
                && !set.model_context_injected
                && !set.hidden_route_authority
                && !set.hidden_cloud_fallback_allowed
                && metrics.route_mutation_count == 0
                && metrics.model_context_injection_count == 0
                && metrics.hidden_authority_count == 0
                && red_pass(&red_results, "route_mutation")
                && red_pass(&red_results, "context_injection")
                && red_pass(&red_results, "hidden_authority")
                && red_pass(&red_results, "hidden_cloud"),
        ),
        (
            "product_and_large_model_claims_rejected",
            !set.product_capability_promoted
                && !set.live_large_model_claimed
                && !set.ssd_as_ram_claimed
                && red_pass(&red_results, "product_promoted")
                && red_pass(&red_results, "live_large_model")
                && red_pass(&red_results, "ssd_as_ram")
                && red_pass(&red_results, "product_build_mas")
                && red_pass(&red_results, "pro_status_live")
                && red_pass(&red_results, "status_source_fetched")
                && red_pass(&red_results, "tier_t2")
                && red_pass(&red_results, "kind_archive_digest"),
        ),
        (
            "large_local_model_research_bias_preserved",
            set.proof_refs.visible_summary.contains("large local model")
                && set.proof_refs.visible_summary.contains("no live dense 70B")
                && set
                    .proof_refs
                    .visible_summary
                    .contains("no hidden route authority"),
        ),
        (
            "reversed_order_address_deterministic",
            set.set_address == reversed.set_address
                && source_byte_manifest_digest(&set) == source_byte_manifest_digest(&reversed),
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

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_entry_count",
        metrics.required_entry_count,
        "==",
        22,
        "entries",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "root_bucket_count",
        metrics.root_bucket_count,
        "==",
        15,
        "buckets",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_tree_entry_count",
        metrics.total_tree_entry_count,
        "==",
        EXPECTED_TREE_ENTRY_COUNT,
        "entries",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_blob_count",
        metrics.blob_count,
        "==",
        EXPECTED_BLOB_COUNT,
        "blobs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_tree_node_count",
        metrics.tree_node_count,
        "==",
        EXPECTED_TREE_NODE_COUNT,
        "trees",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_total_blob_bytes",
        metrics.total_blob_bytes,
        "==",
        EXPECTED_TOTAL_BLOB_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        ">=",
        RED_FIXTURE_FLOOR,
        "fixtures",
    );
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
        "source_byte_manifest_address",
        &set.set_address.to_string(),
        "turbovec_real_adapter_source_byte_manifest_probe:",
        "uas_address",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        TURBOVEC_REAL_ADAPTER_SOURCE_BYTE_MANIFEST_NEXT_CURSOR,
        TURBOVEC_REAL_ADAPTER_SOURCE_BYTE_MANIFEST_NEXT_CURSOR,
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
            "kind": "metadata_only_source_manifest_scope",
            "detail": "Pinned TurboVec Git tree metadata only. No repo clone, codeload archive open, raw source read, quarantine file write, product source import, dependency insertion, adapter build, native-link probe, index/model/runtime/provider bytes, route/context authority, or live large-local-model claim."
        })],
        notes: "Builds F-TurboVec-RealAdapterSourceByteManifestProbe as a T1/L1 metadata-only manifest for pinned TurboVec Git tree rows. It makes the large-local-model compression path more buildable by binding critical source/test/build/benchmark/docs rows, root bucket counts, symlink and binary-asset blocks, benchmark caveats, cleanup/rollback, RunEventLog, AnswerPacket, compatibility fence, and no-product-graph proof before source inspection or adapter rewrite can proceed. L2 capability and L3 user-facing model surfaces remain unchanged.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_fetch_lease_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec fetch-lease gate has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_REAL_ADAPTER_SOURCE_BYTE_MANIFEST_CURSOR)
    {
        return Err("upstream fetch-lease gate does not point at source-byte manifest".into());
    }
    for axis in [
        "/pass_per_axis/upstream_sandbox_layout_bound",
        "/pass_per_axis/source_identity_and_revision_bound",
        "/pass_per_axis/fetch_url_pinned_and_transport_bound",
        "/pass_per_axis/quarantine_target_paths_bound",
        "/pass_per_axis/lease_policy_fail_closed",
        "/pass_per_axis/fetch_phases_complete",
        "/pass_per_axis/proof_surfaces_required",
        "/pass_per_axis/bytes_remain_zero",
        "/pass_per_axis/no_product_graph_or_dependency",
        "/pass_per_axis/no_native_link_runtime_or_model_bytes",
        "/pass_per_axis/no_route_context_or_hidden_authority",
        "/pass_per_axis/product_and_large_model_claims_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(format!("upstream fetch-lease axis missing or false: {axis}").into());
        }
    }
    let address = value
        .pointer("/measurements/fetch_lease_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("upstream fetch-lease address missing")?;
    Ok(UasAddress::from_str(address)?)
}

#[allow(clippy::too_many_arguments)]
fn build_set(
    upstream: UasAddress,
    source: TurboVecSourceManifestSource,
    entries: Vec<TurboVecSourceManifestEntry>,
    buckets: Vec<TurboVecSourceManifestRootBucket>,
    policy: TurboVecSourceManifestPolicy,
    proof_refs: TurboVecSourceManifestProofRefs,
    byte_ledger: TurboVecSourceManifestByteLedger,
    product_build: ProductBuild,
    pro_status: ProStatus,
    status: TurboVecSourceManifestStatus,
    promotion_tier: TurboVecSourceManifestTier,
    manifest_kind: TurboVecSourceManifestKind,
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<TurboVecRealAdapterSourceByteManifestProbeSet, Box<dyn std::error::Error>> {
    Ok(TurboVecRealAdapterSourceByteManifestProbeSet::from_parts(
        upstream,
        source,
        entries,
        buckets,
        policy,
        proof_refs,
        byte_ledger,
        product_build,
        pro_status,
        status,
        promotion_tier,
        manifest_kind,
        organs(),
        product_capability_promoted,
        route_mutation_allowed,
        model_context_injected,
        hidden_route_authority,
        hidden_cloud_fallback_allowed,
        live_large_model_claimed,
        ssd_as_ram_claimed,
    )?)
}

fn source() -> TurboVecSourceManifestSource {
    TurboVecSourceManifestSource {
        source_ref: format!("source_manifest:turbovec:{PINNED_REVISION}"),
        source_url: SOURCE_URL.to_string(),
        tree_api_url: TREE_API_URL.to_string(),
        codeload_url: CODELOAD_URL.to_string(),
        pinned_revision: PINNED_REVISION.to_string(),
        current_head_revision: PINNED_REVISION.to_string(),
        tree_truncated: false,
        tree_entry_count: EXPECTED_TREE_ENTRY_COUNT,
        blob_count: EXPECTED_BLOB_COUNT,
        tree_node_count: EXPECTED_TREE_NODE_COUNT,
        total_blob_bytes: EXPECTED_TOTAL_BLOB_BYTES,
        quarantine_root: QUARANTINE_ROOT.to_string(),
    }
}

fn entry(
    path: &str,
    sha: &str,
    byte_len: u64,
    mode: &str,
    disposition: TurboVecSourceManifestDisposition,
) -> TurboVecSourceManifestEntry {
    TurboVecSourceManifestEntry {
        path: path.to_string(),
        mode: mode.to_string(),
        git_blob_sha: sha.to_string(),
        byte_len,
        disposition,
        raw_content_read: false,
        source_inspection_allowed_now: false,
        product_import_allowed: false,
        native_link_probe_allowed: false,
    }
}

fn entries() -> Vec<TurboVecSourceManifestEntry> {
    use TurboVecSourceManifestDisposition::*;
    vec![
        entry(
            "LICENSE",
            "e62ad7c6028ad9b2f9b4c1776dc7d4a9c942fced",
            1068,
            "100644",
            ProvenanceOnly,
        ),
        entry(
            "README.md",
            "1bcd3121da5c5da47e2259adf1959f9df6af06ef",
            13593,
            "100644",
            DocumentationOnly,
        ),
        entry(
            "Cargo.toml",
            "9bf15f9f5eba2de42db231e9235c4181f620277f",
            366,
            "100644",
            ProvenanceOnly,
        ),
        entry(
            "Cargo.lock",
            "54548a61cb58347074bbbd78537439d75ab24a69",
            30548,
            "100644",
            ProvenanceOnly,
        ),
        entry(
            ".cargo/config.toml",
            "530c5b457b211df82dcab3d6a8751c33b514f1ba",
            980,
            "100644",
            NativeLinkBlocked,
        ),
        entry(
            "benchmarks/rabitq_poc/recall_grid.png",
            "39d79d4f328c4d6d1cfcb8588fb5b01220d95532",
            181829,
            "100644",
            BinaryAssetBlocked,
        ),
        entry(
            "benchmarks/suite/recall_d1536_4bit.py",
            "d82cc28657b6348e7d60d19ddd9c889d7dec2d54",
            2737,
            "100644",
            BenchmarkClaimOnly,
        ),
        entry(
            "benchmarks/suite/speed_d1536_4bit_arm_mt.py",
            "357e10e413956b86edf7276cf6fdcdd65a519acd",
            1662,
            "100644",
            BenchmarkClaimOnly,
        ),
        entry(
            "docs/api.md",
            "a6f603985f39e8db9f917c55a3cef8903340ee82",
            8703,
            "100644",
            DocumentationOnly,
        ),
        entry(
            "examples/downstream-smoke/Cargo.toml",
            "76ada77fc7c563a952d090e9e5d4302444eecb7a",
            522,
            "100644",
            TestFixtureCandidate,
        ),
        entry(
            "turbovec/Cargo.toml",
            "b48103b6c8b826501d13cfde926d9e9d3f118953",
            1003,
            "100644",
            RustCoreCandidate,
        ),
        entry(
            "turbovec/build.rs",
            "7695df94659cbdacbf2915956c18e29bea9a917d",
            917,
            "100644",
            NativeLinkBlocked,
        ),
        entry(
            "turbovec/src/lib.rs",
            "46aa6d0e0ece49b37d9b3e2559f3657fe11dcbc0",
            31155,
            "100644",
            RustCoreCandidate,
        ),
        entry(
            "turbovec/src/search.rs",
            "4fda9433ad90c55fb6fe339d75ccacbac9596140",
            75676,
            "100644",
            RustCoreCandidate,
        ),
        entry(
            "turbovec/src/id_map.rs",
            "96e2444718c2f4d1f588bc2cc2f6623efef91de2",
            11984,
            "100644",
            RustCoreCandidate,
        ),
        entry(
            "turbovec/src/io.rs",
            "452dcb433f6524ccb8837e6e7e1dc87fde4d3f06",
            9855,
            "100644",
            RustCoreCandidate,
        ),
        entry(
            "turbovec/tests/filtering.rs",
            "c923e7c0af84641d8acfdba1f1ad68ef5fb8c8d2",
            16986,
            "100644",
            TestFixtureCandidate,
        ),
        entry(
            "turbovec/tests/input_validation.rs",
            "664b8749f8eaeba961850d33fae432facf0356e5",
            7686,
            "100644",
            TestFixtureCandidate,
        ),
        entry(
            "turbovec-python/Cargo.toml",
            "9cc4a980cfb37e6aaec85c30c8d36f1cdd5919b2",
            314,
            "100644",
            PythonBindingCandidate,
        ),
        entry(
            "turbovec-python/README.md",
            "32d46ee883b58d6a383eed06eb98f33aa6530ded",
            12,
            "120000",
            SymlinkBlocked,
        ),
        entry(
            "turbovec-python/pyproject.toml",
            "166cd434a337d3d861649b0aa7471b8920cec99c",
            1684,
            "100644",
            PythonBindingCandidate,
        ),
        entry(
            "turbovec-python/python/turbovec/llama_index.py",
            "c259150dddd428d1e39046aa8d9b50f637c6e6a6",
            27928,
            "100644",
            IntegrationBlocked,
        ),
    ]
}

fn buckets() -> Vec<TurboVecSourceManifestRootBucket> {
    [
        (".cargo", 1),
        (".claude", 1),
        (".github", 5),
        (".gitignore", 1),
        ("CHANGELOG.md", 1),
        ("CONTRIBUTING.md", 1),
        ("Cargo.lock", 1),
        ("Cargo.toml", 1),
        ("LICENSE", 1),
        ("README.md", 1),
        ("benchmarks", 106),
        ("docs", 14),
        ("examples", 3),
        ("turbovec", 27),
        ("turbovec-python", 16),
    ]
    .into_iter()
    .map(|(root, blob_count)| TurboVecSourceManifestRootBucket {
        root: root.to_string(),
        blob_count,
        required_for_manifest: true,
    })
    .collect()
}

fn policy() -> TurboVecSourceManifestPolicy {
    TurboVecSourceManifestPolicy::fail_closed()
}

fn proof_refs() -> TurboVecSourceManifestProofRefs {
    TurboVecSourceManifestProofRefs {
        fetch_lease_ref: "artifact:turbovec_real_adapter_fetch_lease_probe:result".to_string(),
        provenance_ref: "provenance:turbovec-source-manifest:github-tree-metadata".to_string(),
        rollback_ref: "rollback:turbovec-source-manifest:delete-manifest-and-quarantine"
            .to_string(),
        cleanup_ref: "cleanup:turbovec-source-manifest:tree-manifest-expiry".to_string(),
        no_product_graph_ref:
            "no_product_graph:turbovec-source-manifest:no-cargo-or-build-membership".to_string(),
        run_event_log_ref: "run_event_log:turbovec-source-manifest:tree-metadata-only"
            .to_string(),
        answer_packet_ref:
            "answer_packet:turbovec-source-manifest:visible-no-source-inspection".to_string(),
        compatibility_fence_ref:
            "compat:turbovec-source-manifest:mas-pro-quarantine-only".to_string(),
        native_link_block_ref:
            "native_link:turbovec-source-manifest:build-rs-and-cargo-config-blocked".to_string(),
        benchmark_caveat_ref:
            "benchmark_caveat:turbovec-source-manifest:benchmarks-non-authoritative"
                .to_string(),
        visible_summary: "This source-byte manifest preserves the large local model research path by binding pinned TurboVec Git tree metadata only: file paths, modes, blob SHAs, aggregate counts, root buckets, and critical source/test/build/benchmark/docs rows. Raw source content is unread, archives are unfetched, quarantine files are unwritten, product graphs and dependencies stay untouched, native-link/build/runtime actions remain blocked, benchmark claims are non-authoritative, no model/index/runtime/provider bytes are loaded, no hidden route authority or hidden cloud fallback is granted, there is no live dense 70B claim, and no SSD-as-RAM claim.".to_string(),
    }
}

fn byte_ledger() -> TurboVecSourceManifestByteLedger {
    TurboVecSourceManifestByteLedger::metadata_only(TREE_METADATA_BYTES_READ)
}

fn organs() -> Vec<TurboVecIndexOrgan> {
    vec![
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ]
}

fn red_fixture_results(upstream: &UasAddress) -> Vec<(String, bool)> {
    let mut results = Vec::new();

    push_case(&mut results, "bad_upstream_cursor", || {
        let bad = UasAddress::from_str(
            "wrong_turbovec_gate:f59dcce8a5c6691d3cf9c132f99e80c44a42b85c784d9b49745d1d435d26d2f5@1779040901000",
        );
        match bad {
            Ok(address) => default_with_upstream(address).is_err(),
            Err(_) => true,
        }
    });

    for (name, field) in [
        ("bad_source_ref", SourceField::SourceRef),
        ("bad_source_url", SourceField::SourceUrl),
        ("bad_tree_api_url", SourceField::TreeApiUrl),
        ("bad_codeload_url", SourceField::CodeloadUrl),
        ("bad_pinned_revision", SourceField::PinnedRevision),
        ("bad_current_head", SourceField::CurrentHead),
        ("tree_truncated", SourceField::TreeTruncated),
        ("tree_entry_count_drift", SourceField::TreeEntryCount),
        ("blob_count_drift", SourceField::BlobCount),
        ("tree_node_count_drift", SourceField::TreeNodeCount),
        ("total_blob_bytes_drift", SourceField::TotalBlobBytes),
        ("bad_quarantine_root", SourceField::QuarantineRoot),
    ] {
        push_case(&mut results, name, || {
            let mut source = source();
            mutate_source(&mut source, field);
            default_with_source(upstream.clone(), source).is_err()
        });
    }

    for path in [
        "LICENSE",
        "Cargo.toml",
        "turbovec/src/search.rs",
        "turbovec-python/pyproject.toml",
    ] {
        let name = format!("missing_{}", path.replace(['/', '.'], "_"));
        push_case(&mut results, &name, || {
            let entries: Vec<_> = entries()
                .into_iter()
                .filter(|entry| entry.path != path)
                .collect();
            default_with_entries(upstream.clone(), entries).is_err()
        });
    }
    push_case(&mut results, "duplicate_entry_path", || {
        let mut entries = entries();
        entries[1].path = entries[0].path.clone();
        default_with_entries(upstream.clone(), entries).is_err()
    });
    for (name, mutation) in [
        ("bad_entry_sha", EntryMutation::BadSha),
        ("bad_entry_size", EntryMutation::BadSize),
        ("bad_entry_mode", EntryMutation::BadMode),
        ("zero_entry_size", EntryMutation::ZeroSize),
        (
            "absolute_entry_path",
            EntryMutation::Path("/tmp/turbovec/src/lib.rs"),
        ),
        (
            "traversal_entry_path",
            EntryMutation::Path("turbovec/src/../Cargo.toml"),
        ),
        ("empty_entry_path", EntryMutation::Path("")),
        (
            "dot_entry_path",
            EntryMutation::Path("turbovec/./src/lib.rs"),
        ),
        (
            "double_slash_entry_path",
            EntryMutation::Path("turbovec//src/lib.rs"),
        ),
        (
            "backslash_entry_path",
            EntryMutation::Path("turbovec\\src\\lib.rs"),
        ),
        (
            "product_path_agent_core",
            EntryMutation::Path("agent_core/src/uas/turbovec.rs"),
        ),
        (
            "product_path_epistemos",
            EntryMutation::Path("Epistemos/Engine/TurboVec.swift"),
        ),
        (
            "product_path_graph_engine",
            EntryMutation::Path("graph-engine/src/turbovec.rs"),
        ),
        (
            "product_path_tools",
            EntryMutation::Path("Tools/falsifiers/f_turbovec.sh"),
        ),
        (
            "product_path_artifacts",
            EntryMutation::Path("artifacts/falsifiers/turbovec/result.json"),
        ),
        (
            "product_path_target",
            EntryMutation::Path("target/debug/turbovec"),
        ),
        ("symlink_not_blocked", EntryMutation::SymlinkNotBlocked),
        (
            "binary_asset_import_allowed",
            EntryMutation::BinaryAssetImportAllowed,
        ),
        (
            "benchmark_claim_authoritative",
            EntryMutation::BenchmarkClaimAuthoritative,
        ),
        (
            "source_inspection_allowed_on_entry",
            EntryMutation::SourceInspectionAllowed,
        ),
        (
            "native_link_allowed_on_entry",
            EntryMutation::NativeLinkAllowed,
        ),
    ] {
        push_case(&mut results, name, || {
            let mut entries = entries();
            mutate_entry(&mut entries, mutation);
            default_with_entries(upstream.clone(), entries).is_err()
        });
    }

    for root in ["benchmarks", "turbovec", "turbovec-python"] {
        let name = format!("missing_root_{root}");
        push_case(&mut results, &name, || {
            let buckets: Vec<_> = buckets()
                .into_iter()
                .filter(|bucket| bucket.root != root)
                .collect();
            default_with_buckets(upstream.clone(), buckets).is_err()
        });
    }
    push_case(&mut results, "bad_root_count", || {
        let mut buckets = buckets();
        buckets[0].blob_count += 1;
        default_with_buckets(upstream.clone(), buckets).is_err()
    });
    push_case(&mut results, "duplicate_root_bucket", || {
        let mut buckets = buckets();
        buckets[1].root = buckets[0].root.clone();
        default_with_buckets(upstream.clone(), buckets).is_err()
    });
    push_case(&mut results, "root_not_required", || {
        let mut buckets = buckets();
        buckets[0].required_for_manifest = false;
        default_with_buckets(upstream.clone(), buckets).is_err()
    });

    for (name, mutation) in [
        (
            "policy_tree_metadata_not_only",
            PolicyMutation::TreeMetadataNotOnly,
        ),
        ("policy_raw_content_read", PolicyMutation::RawContentRead),
        (
            "policy_source_bytes_fetched",
            PolicyMutation::SourceBytesFetched,
        ),
        ("policy_codeload_opened", PolicyMutation::CodeloadOpened),
        (
            "policy_quarantine_written",
            PolicyMutation::QuarantineWritten,
        ),
        (
            "policy_source_inspection_allowed",
            PolicyMutation::SourceInspectionAllowed,
        ),
        ("policy_product_import", PolicyMutation::ProductImport),
        ("policy_dependency", PolicyMutation::Dependency),
        ("policy_native_link", PolicyMutation::NativeLink),
        ("policy_runtime", PolicyMutation::Runtime),
        ("policy_index_model", PolicyMutation::IndexModel),
        (
            "policy_symlink_not_blocked",
            PolicyMutation::SymlinkNotBlocked,
        ),
        (
            "policy_binary_not_blocked",
            PolicyMutation::BinaryNotBlocked,
        ),
        (
            "policy_benchmark_authoritative",
            PolicyMutation::BenchmarkAuthoritative,
        ),
        (
            "policy_later_witness_not_required",
            PolicyMutation::LaterWitnessNotRequired,
        ),
        (
            "policy_cleanup_not_required",
            PolicyMutation::CleanupNotRequired,
        ),
        (
            "policy_answer_packet_not_required",
            PolicyMutation::AnswerPacketNotRequired,
        ),
    ] {
        push_case(&mut results, name, || {
            let mut policy = policy();
            mutate_policy(&mut policy, mutation);
            default_with_policy(upstream.clone(), policy).is_err()
        });
    }

    for (name, field) in [
        ("bad_fetch_lease_ref", ProofField::FetchLease),
        ("bad_provenance_ref", ProofField::Provenance),
        ("bad_rollback_ref", ProofField::Rollback),
        ("bad_cleanup_ref", ProofField::Cleanup),
        ("bad_no_product_graph_ref", ProofField::NoProductGraph),
        ("bad_run_event_log_ref", ProofField::RunEventLog),
        ("bad_answer_packet_ref", ProofField::AnswerPacket),
        ("bad_compatibility_ref", ProofField::Compatibility),
        ("bad_native_link_ref", ProofField::NativeLink),
        ("bad_benchmark_caveat_ref", ProofField::BenchmarkCaveat),
        ("short_visible_summary", ProofField::VisibleSummary),
    ] {
        push_case(&mut results, name, || {
            let mut refs = proof_refs();
            mutate_proof(&mut refs, field);
            default_with_proof(upstream.clone(), refs).is_err()
        });
    }

    for (name, mutation) in [
        ("metadata_bytes_zero", ByteMutation::MetadataZero),
        ("metadata_bytes_over", ByteMutation::MetadataOver),
        (
            "declared_blob_bytes_mismatch",
            ByteMutation::DeclaredBlobMismatch,
        ),
        ("raw_source_bytes_read", ByteMutation::RawSourceBytes),
        (
            "source_archive_bytes_fetched",
            ByteMutation::SourceArchiveBytes,
        ),
        (
            "local_quarantine_bytes_written",
            ByteMutation::QuarantineBytes,
        ),
        ("copied_product_file", ByteMutation::CopiedProductFile),
        ("product_dependency", ByteMutation::ProductDependency),
        (
            "imported_external_crate",
            ByteMutation::ImportedExternalCrate,
        ),
        ("built_external_binary", ByteMutation::BuiltExternalBinary),
        ("native_link_probe", ByteMutation::NativeLinkProbe),
        ("opened_product_index", ByteMutation::OpenedProductIndex),
        ("model_bytes_loaded", ByteMutation::ModelBytesLoaded),
        (
            "runtime_model_bytes_loaded",
            ByteMutation::RuntimeModelBytesLoaded,
        ),
        ("provider_call", ByteMutation::ProviderCall),
    ] {
        push_case(&mut results, name, || {
            let mut ledger = byte_ledger();
            mutate_ledger(&mut ledger, mutation);
            default_with_ledger(upstream.clone(), ledger).is_err()
        });
    }

    for (name, flag) in [
        ("route_mutation", ClaimFlag::RouteMutation),
        ("context_injection", ClaimFlag::ContextInjection),
        ("hidden_authority", ClaimFlag::HiddenAuthority),
        ("hidden_cloud", ClaimFlag::HiddenCloud),
        ("product_promoted", ClaimFlag::ProductPromoted),
        ("live_large_model", ClaimFlag::LiveLargeModel),
        ("ssd_as_ram", ClaimFlag::SsdAsRam),
    ] {
        push_case(&mut results, name, || {
            default_with_claim_flag(upstream.clone(), flag).is_err()
        });
    }

    for (name, build, pro_status, status, tier, kind) in [
        (
            "product_build_mas",
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            TurboVecSourceManifestStatus::MetadataOnlyManifest,
            TurboVecSourceManifestTier::T1L1Metadata,
            TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
        ),
        (
            "pro_status_live",
            ProductBuild::Pro,
            ProStatus::Live,
            TurboVecSourceManifestStatus::MetadataOnlyManifest,
            TurboVecSourceManifestTier::T1L1Metadata,
            TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
        ),
        (
            "status_source_fetched",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceManifestStatus::SourceFetchedByLaterWitness,
            TurboVecSourceManifestTier::T1L1Metadata,
            TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
        ),
        (
            "tier_t2",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceManifestStatus::MetadataOnlyManifest,
            TurboVecSourceManifestTier::T2L2Route,
            TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
        ),
        (
            "kind_archive_digest",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceManifestStatus::MetadataOnlyManifest,
            TurboVecSourceManifestTier::T1L1Metadata,
            TurboVecSourceManifestKind::CodeloadArchiveDigestByLaterWitness,
        ),
    ] {
        push_case(&mut results, name, || {
            build_set(
                upstream.clone(),
                source(),
                entries(),
                buckets(),
                policy(),
                proof_refs(),
                byte_ledger(),
                build,
                pro_status,
                status,
                tier,
                kind,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err()
        });
    }

    results
}

fn default_with_upstream(
    upstream: UasAddress,
) -> Result<TurboVecRealAdapterSourceByteManifestProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        source(),
        entries(),
        buckets(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceManifestStatus::MetadataOnlyManifest,
        TurboVecSourceManifestTier::T1L1Metadata,
        TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn default_with_source(
    upstream: UasAddress,
    source: TurboVecSourceManifestSource,
) -> Result<TurboVecRealAdapterSourceByteManifestProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        source,
        entries(),
        buckets(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceManifestStatus::MetadataOnlyManifest,
        TurboVecSourceManifestTier::T1L1Metadata,
        TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn default_with_entries(
    upstream: UasAddress,
    entries: Vec<TurboVecSourceManifestEntry>,
) -> Result<TurboVecRealAdapterSourceByteManifestProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        source(),
        entries,
        buckets(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceManifestStatus::MetadataOnlyManifest,
        TurboVecSourceManifestTier::T1L1Metadata,
        TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn default_with_buckets(
    upstream: UasAddress,
    buckets: Vec<TurboVecSourceManifestRootBucket>,
) -> Result<TurboVecRealAdapterSourceByteManifestProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        source(),
        entries(),
        buckets,
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceManifestStatus::MetadataOnlyManifest,
        TurboVecSourceManifestTier::T1L1Metadata,
        TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn default_with_policy(
    upstream: UasAddress,
    policy: TurboVecSourceManifestPolicy,
) -> Result<TurboVecRealAdapterSourceByteManifestProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        source(),
        entries(),
        buckets(),
        policy,
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceManifestStatus::MetadataOnlyManifest,
        TurboVecSourceManifestTier::T1L1Metadata,
        TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn default_with_proof(
    upstream: UasAddress,
    proof_refs: TurboVecSourceManifestProofRefs,
) -> Result<TurboVecRealAdapterSourceByteManifestProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        source(),
        entries(),
        buckets(),
        policy(),
        proof_refs,
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceManifestStatus::MetadataOnlyManifest,
        TurboVecSourceManifestTier::T1L1Metadata,
        TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn default_with_ledger(
    upstream: UasAddress,
    ledger: TurboVecSourceManifestByteLedger,
) -> Result<TurboVecRealAdapterSourceByteManifestProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        source(),
        entries(),
        buckets(),
        policy(),
        proof_refs(),
        ledger,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceManifestStatus::MetadataOnlyManifest,
        TurboVecSourceManifestTier::T1L1Metadata,
        TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn default_with_claim_flag(
    upstream: UasAddress,
    flag: ClaimFlag,
) -> Result<TurboVecRealAdapterSourceByteManifestProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        source(),
        entries(),
        buckets(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceManifestStatus::MetadataOnlyManifest,
        TurboVecSourceManifestTier::T1L1Metadata,
        TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
        matches!(flag, ClaimFlag::ProductPromoted),
        matches!(flag, ClaimFlag::RouteMutation),
        matches!(flag, ClaimFlag::ContextInjection),
        matches!(flag, ClaimFlag::HiddenAuthority),
        matches!(flag, ClaimFlag::HiddenCloud),
        matches!(flag, ClaimFlag::LiveLargeModel),
        matches!(flag, ClaimFlag::SsdAsRam),
    )
}

fn mutate_source(source: &mut TurboVecSourceManifestSource, field: SourceField) {
    match field {
        SourceField::SourceRef => source.source_ref = "source_manifest:wrong".to_string(),
        SourceField::SourceUrl => {
            source.source_url = "https://github.com/other/turbovec".to_string()
        }
        SourceField::TreeApiUrl => {
            source.tree_api_url =
                "https://api.github.com/repos/RyanCodrai/turbovec/git/trees/main?recursive=1"
                    .to_string()
        }
        SourceField::CodeloadUrl => {
            source.codeload_url =
                "https://codeload.github.com/RyanCodrai/turbovec/tar.gz/main".to_string()
        }
        SourceField::PinnedRevision => {
            source.pinned_revision = "EFE29A184986CBF562A9847C2AC52A2990BFACA2".to_string()
        }
        SourceField::CurrentHead => {
            source.current_head_revision = "0000000000000000000000000000000000000000".to_string()
        }
        SourceField::TreeTruncated => source.tree_truncated = true,
        SourceField::TreeEntryCount => source.tree_entry_count -= 1,
        SourceField::BlobCount => source.blob_count -= 1,
        SourceField::TreeNodeCount => source.tree_node_count -= 1,
        SourceField::TotalBlobBytes => source.total_blob_bytes -= 1,
        SourceField::QuarantineRoot => {
            source.quarantine_root = ".epistemos-quarantine/turbovec/wrong".to_string()
        }
    }
}

fn mutate_entry(entries: &mut [TurboVecSourceManifestEntry], mutation: EntryMutation) {
    match mutation {
        EntryMutation::BadSha => entries[0].git_blob_sha = "bad".to_string(),
        EntryMutation::BadSize => entries[0].byte_len += 1,
        EntryMutation::BadMode => entries[0].mode = "100755".to_string(),
        EntryMutation::ZeroSize => entries[0].byte_len = 0,
        EntryMutation::Path(path) => entries[0].path = path.to_string(),
        EntryMutation::SymlinkNotBlocked => {
            let entry = entries
                .iter_mut()
                .find(|entry| entry.path == "turbovec-python/README.md")
                .expect("symlink fixture");
            entry.disposition = TurboVecSourceManifestDisposition::DocumentationOnly;
        }
        EntryMutation::BinaryAssetImportAllowed => {
            let entry = entries
                .iter_mut()
                .find(|entry| entry.path.ends_with("recall_grid.png"))
                .expect("binary fixture");
            entry.product_import_allowed = true;
        }
        EntryMutation::BenchmarkClaimAuthoritative => {
            let entry = entries
                .iter_mut()
                .find(|entry| entry.path.contains("benchmarks/suite"))
                .expect("benchmark fixture");
            entry.disposition = TurboVecSourceManifestDisposition::RustCoreCandidate;
        }
        EntryMutation::SourceInspectionAllowed => entries[0].source_inspection_allowed_now = true,
        EntryMutation::NativeLinkAllowed => entries[0].native_link_probe_allowed = true,
    }
}

fn mutate_policy(policy: &mut TurboVecSourceManifestPolicy, mutation: PolicyMutation) {
    match mutation {
        PolicyMutation::TreeMetadataNotOnly => policy.github_tree_metadata_only = false,
        PolicyMutation::RawContentRead => policy.raw_content_read = true,
        PolicyMutation::SourceBytesFetched => policy.source_bytes_fetched = true,
        PolicyMutation::CodeloadOpened => policy.codeload_archive_opened = true,
        PolicyMutation::QuarantineWritten => policy.local_quarantine_files_written = true,
        PolicyMutation::SourceInspectionAllowed => policy.source_inspection_allowed_now = true,
        PolicyMutation::ProductImport => policy.product_import_allowed = true,
        PolicyMutation::Dependency => policy.product_dependency_allowed = true,
        PolicyMutation::NativeLink => policy.native_link_probe_allowed = true,
        PolicyMutation::Runtime => policy.runtime_execution_allowed = true,
        PolicyMutation::IndexModel => policy.index_or_model_bytes_allowed = true,
        PolicyMutation::SymlinkNotBlocked => policy.symlink_targets_blocked = false,
        PolicyMutation::BinaryNotBlocked => policy.binary_assets_blocked = false,
        PolicyMutation::BenchmarkAuthoritative => policy.benchmark_claims_non_authoritative = false,
        PolicyMutation::LaterWitnessNotRequired => {
            policy.source_inspection_requires_later_witness = false
        }
        PolicyMutation::CleanupNotRequired => policy.cleanup_replay_required = false,
        PolicyMutation::AnswerPacketNotRequired => policy.answer_packet_required = false,
    }
}

fn mutate_proof(refs: &mut TurboVecSourceManifestProofRefs, field: ProofField) {
    match field {
        ProofField::FetchLease => refs.fetch_lease_ref = "artifact:wrong:result".to_string(),
        ProofField::Provenance => refs.provenance_ref = "bad:provenance".to_string(),
        ProofField::Rollback => refs.rollback_ref = "bad:rollback".to_string(),
        ProofField::Cleanup => refs.cleanup_ref = "bad:cleanup".to_string(),
        ProofField::NoProductGraph => refs.no_product_graph_ref = "bad:graph".to_string(),
        ProofField::RunEventLog => refs.run_event_log_ref = "bad:log".to_string(),
        ProofField::AnswerPacket => refs.answer_packet_ref = "bad:answer".to_string(),
        ProofField::Compatibility => refs.compatibility_fence_ref = "bad:compat".to_string(),
        ProofField::NativeLink => refs.native_link_block_ref = "bad:native".to_string(),
        ProofField::BenchmarkCaveat => refs.benchmark_caveat_ref = "bad:bench".to_string(),
        ProofField::VisibleSummary => refs.visible_summary = "too short".to_string(),
    }
}

fn mutate_ledger(ledger: &mut TurboVecSourceManifestByteLedger, mutation: ByteMutation) {
    match mutation {
        ByteMutation::MetadataZero => ledger.github_tree_metadata_bytes_read = 0,
        ByteMutation::MetadataOver => ledger.github_tree_metadata_bytes_read = 256 * 1024,
        ByteMutation::DeclaredBlobMismatch => ledger.declared_total_blob_bytes -= 1,
        ByteMutation::RawSourceBytes => ledger.raw_source_bytes_read = 1,
        ByteMutation::SourceArchiveBytes => ledger.source_archive_bytes_fetched = 1,
        ByteMutation::QuarantineBytes => ledger.local_quarantine_bytes_written = 1,
        ByteMutation::CopiedProductFile => ledger.copied_product_file_count = 1,
        ByteMutation::ProductDependency => ledger.product_dependency_count = 1,
        ByteMutation::ImportedExternalCrate => ledger.imported_external_crate_count = 1,
        ByteMutation::BuiltExternalBinary => ledger.built_external_binary_count = 1,
        ByteMutation::NativeLinkProbe => ledger.native_link_probe_count = 1,
        ByteMutation::OpenedProductIndex => ledger.opened_product_index_bytes = 1,
        ByteMutation::ModelBytesLoaded => ledger.model_bytes_loaded = 1,
        ByteMutation::RuntimeModelBytesLoaded => ledger.runtime_model_bytes_loaded = 1,
        ByteMutation::ProviderCall => ledger.provider_calls_made = 1,
    }
}

fn push_case<F: FnOnce() -> bool>(results: &mut Vec<(String, bool)>, name: &str, f: F) {
    results.push((name.to_string(), f()));
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
    expected_prefix: &str,
    unit: &str,
) {
    let passed = actual.starts_with(expected_prefix);
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
            operator: "starts_with".to_string(),
            value: serde_json::Value::String(expected_prefix.to_string()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), passed);
}

#[derive(Clone, Copy)]
// UAS-EXEMPT: local red-fixture mutation helper for this falsifier binary.
enum SourceField {
    SourceRef,
    SourceUrl,
    TreeApiUrl,
    CodeloadUrl,
    PinnedRevision,
    CurrentHead,
    TreeTruncated,
    TreeEntryCount,
    BlobCount,
    TreeNodeCount,
    TotalBlobBytes,
    QuarantineRoot,
}

#[derive(Clone, Copy)]
// UAS-EXEMPT: local red-fixture mutation helper for this falsifier binary.
enum EntryMutation {
    BadSha,
    BadSize,
    BadMode,
    ZeroSize,
    Path(&'static str),
    SymlinkNotBlocked,
    BinaryAssetImportAllowed,
    BenchmarkClaimAuthoritative,
    SourceInspectionAllowed,
    NativeLinkAllowed,
}

#[derive(Clone, Copy)]
// UAS-EXEMPT: local red-fixture mutation helper for this falsifier binary.
enum PolicyMutation {
    TreeMetadataNotOnly,
    RawContentRead,
    SourceBytesFetched,
    CodeloadOpened,
    QuarantineWritten,
    SourceInspectionAllowed,
    ProductImport,
    Dependency,
    NativeLink,
    Runtime,
    IndexModel,
    SymlinkNotBlocked,
    BinaryNotBlocked,
    BenchmarkAuthoritative,
    LaterWitnessNotRequired,
    CleanupNotRequired,
    AnswerPacketNotRequired,
}

#[derive(Clone, Copy)]
// UAS-EXEMPT: local red-fixture mutation helper for this falsifier binary.
enum ProofField {
    FetchLease,
    Provenance,
    Rollback,
    Cleanup,
    NoProductGraph,
    RunEventLog,
    AnswerPacket,
    Compatibility,
    NativeLink,
    BenchmarkCaveat,
    VisibleSummary,
}

#[derive(Clone, Copy)]
// UAS-EXEMPT: local red-fixture mutation helper for this falsifier binary.
enum ByteMutation {
    MetadataZero,
    MetadataOver,
    DeclaredBlobMismatch,
    RawSourceBytes,
    SourceArchiveBytes,
    QuarantineBytes,
    CopiedProductFile,
    ProductDependency,
    ImportedExternalCrate,
    BuiltExternalBinary,
    NativeLinkProbe,
    OpenedProductIndex,
    ModelBytesLoaded,
    RuntimeModelBytesLoaded,
    ProviderCall,
}

#[derive(Clone, Copy)]
// UAS-EXEMPT: local red-fixture mutation helper for this falsifier binary.
enum ClaimFlag {
    RouteMutation,
    ContextInjection,
    HiddenAuthority,
    HiddenCloud,
    ProductPromoted,
    LiveLargeModel,
    SsdAsRam,
}
