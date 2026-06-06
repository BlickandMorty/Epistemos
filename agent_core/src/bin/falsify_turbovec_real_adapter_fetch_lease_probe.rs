//! `falsify_turbovec_real_adapter_fetch_lease_probe`
//!
//! Metadata-only witness for `F-TurboVec-RealAdapterFetchLeaseProbe`.
//! It proves a future, bounded TurboVec source fetch lease can be declared
//! only after the sandbox-layout witness, while still forbidding network fetch,
//! clone/import/build/native-link/runtime work, product dependency insertion,
//! route/context mutation, model/index/provider bytes, and large-local-model
//! product claims.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    fetch_lease_digest, ProStatus, ProductBuild, TurboVecFetchLeaseAction,
    TurboVecFetchLeaseByteLedger, TurboVecFetchLeasePhase, TurboVecFetchLeasePolicy,
    TurboVecFetchLeaseProofRefs, TurboVecFetchLeaseSource, TurboVecFetchLeaseStatus,
    TurboVecFetchLeaseTarget, TurboVecFetchLeaseTier, TurboVecFetchTransport, TurboVecIndexOrgan,
    TurboVecRealAdapterFetchLeaseProbeSet, UasAddress, TURBOVEC_REAL_ADAPTER_FETCH_LEASE_CURSOR,
    TURBOVEC_REAL_ADAPTER_FETCH_LEASE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RealAdapterFetchLeaseProbe";
const FIXTURE_ID: &str = "turbovec_real_adapter_fetch_lease_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_real_adapter_fetch_lease_probe.sh";
const RESULT: &str = "artifacts/falsifiers/turbovec_real_adapter_fetch_lease_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_sandbox_layout_probe/result.json";
const SOURCE_URL: &str = "https://github.com/RyanCodrai/turbovec";
const CLONE_URL: &str = "https://github.com/RyanCodrai/turbovec.git";
const FETCH_URL_PREFIX: &str = "https://codeload.github.com/RyanCodrai/turbovec/tar.gz/";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const QUARANTINE_ROOT: &str =
    ".epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2";
const LEASE_METADATA_BYTES: u64 = 112_000;
const PLANNED_DOWNLOAD_BYTES: u64 = 8 * 1024 * 1024;
const PLANNED_UNPACKED_BYTES: u64 = 32 * 1024 * 1024;
const RED_FIXTURE_FLOOR: u64 = 86;

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
        "{FALSIFIER_ID}: overall_pass={} phases={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["phase_count"].value,
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
    let upstream = upstream_sandbox_layout_address()?;
    let set = build_set(
        upstream.clone(),
        source(),
        target(),
        phases(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecFetchLeaseStatus::MetadataOnlyLease,
        TurboVecFetchLeaseTier::T1L1Metadata,
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
        target(),
        phases().into_iter().rev().collect(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecFetchLeaseStatus::MetadataOnlyLease,
        TurboVecFetchLeaseTier::T1L1Metadata,
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
            "upstream_sandbox_layout_bound",
            set.upstream_sandbox_layout_witness_ref
                == "artifact:turbovec_real_adapter_sandbox_layout_probe:result"
                && set
                    .upstream_sandbox_layout_address
                    .to_string()
                    .starts_with("turbovec_real_adapter_sandbox_layout_probe:")
                && red_pass(&red_results, "bad_upstream_cursor"),
        ),
        (
            "source_identity_and_revision_bound",
            set.source.source_url == SOURCE_URL
                && set.source.clone_url == CLONE_URL
                && set.source.pinned_revision == PINNED_REVISION
                && set.source.current_head_revision == PINNED_REVISION
                && red_pass(&red_results, "bad_source_ref")
                && red_pass(&red_results, "bad_source_url")
                && red_pass(&red_results, "bad_clone_url")
                && red_pass(&red_results, "bad_pinned_revision")
                && red_pass(&red_results, "bad_current_head")
                && red_pass(&red_results, "bad_license_ref")
                && red_pass(&red_results, "bad_commit_ref"),
        ),
        (
            "fetch_url_pinned_and_transport_bound",
            set.source.fetch_url == format!("{FETCH_URL_PREFIX}{PINNED_REVISION}")
                && set.source.transport == TurboVecFetchTransport::GitHubCodeloadTarball
                && red_pass(&red_results, "bad_fetch_url_prefix")
                && red_pass(&red_results, "bad_fetch_url_revision")
                && red_pass(&red_results, "git_clone_transport")
                && red_pass(&red_results, "ssh_clone_transport")
                && red_pass(&red_results, "local_copy_transport")
                && red_pass(&red_results, "registry_transport"),
        ),
        (
            "quarantine_target_paths_bound",
            set.target.quarantine_root == QUARANTINE_ROOT
                && set.target.source_tree_path.ends_with("/source-tree")
                && set.target.temp_download_path.ends_with("/source-tree.tmp")
                && set
                    .target
                    .source_manifest_path
                    .ends_with("/source-manifest.json")
                && set
                    .target
                    .cleanup_tombstone_path
                    .ends_with("/cleanup-tombstones/fetch-lease")
                && red_pass(&red_results, "absolute_target_path")
                && red_pass(&red_results, "traversal_target_path")
                && red_pass(&red_results, "empty_target_path")
                && red_pass(&red_results, "dot_target_path")
                && red_pass(&red_results, "double_slash_target_path")
                && red_pass(&red_results, "backslash_target_path")
                && red_pass(&red_results, "outside_quarantine_root")
                && red_pass(&red_results, "duplicate_target_path")
                && red_pass(&red_results, "product_path_agent_core")
                && red_pass(&red_results, "product_path_epistemos")
                && red_pass(&red_results, "product_path_graph_engine")
                && red_pass(&red_results, "product_path_tools")
                && red_pass(&red_results, "product_path_docs")
                && red_pass(&red_results, "product_path_artifacts_falsifiers")
                && red_pass(&red_results, "product_path_benchmarks")
                && red_pass(&red_results, "product_path_target")
                && red_pass(&red_results, "product_path_git"),
        ),
        (
            "lease_policy_fail_closed",
            set.policy.owner_approval_required
                && !set.policy.owner_approval_granted
                && !set.policy.network_fetch_allowed_now
                && set.policy.future_fetch_requires_later_witness
                && set.policy.source_byte_manifest_required_after_fetch
                && set.policy.no_product_graph_membership
                && set.policy.no_product_dependency_insertion
                && set.policy.no_native_link_probe
                && set.policy.no_runtime_execution
                && set.policy.no_index_or_model_bytes
                && set.policy.cleanup_replay_required
                && set.policy.answer_packet_required
                && set.policy.allowed_action == TurboVecFetchLeaseAction::DeclareLeaseOnly
                && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "network_fetch_allowed_now")
                && red_pass(&red_results, "owner_approval_not_required")
                && red_pass(&red_results, "later_witness_not_required")
                && red_pass(&red_results, "source_manifest_not_required")
                && red_pass(&red_results, "product_graph_membership_allowed")
                && red_pass(&red_results, "product_dependency_allowed")
                && red_pass(&red_results, "native_link_allowed")
                && red_pass(&red_results, "runtime_allowed")
                && red_pass(&red_results, "index_or_model_bytes_allowed")
                && red_pass(&red_results, "cleanup_not_required")
                && red_pass(&red_results, "answer_packet_not_required")
                && red_pass(&red_results, "fetch_archive_action")
                && red_pass(&red_results, "git_clone_action")
                && red_pass(&red_results, "copy_product_action")
                && red_pass(&red_results, "add_dependency_action")
                && red_pass(&red_results, "build_adapter_action")
                && red_pass(&red_results, "native_link_action")
                && red_pass(&red_results, "runtime_route_action"),
        ),
        (
            "fetch_phases_complete",
            metrics.phase_count == 6
                && red_pass(&red_results, "missing_lease_declaration_phase")
                && red_pass(&red_results, "missing_owner_approval_phase")
                && red_pass(&red_results, "missing_byte_cap_phase")
                && red_pass(&red_results, "missing_no_product_graph_phase")
                && red_pass(&red_results, "missing_cleanup_phase")
                && red_pass(&red_results, "missing_answer_packet_phase")
                && red_pass(&red_results, "duplicate_phase"),
        ),
        (
            "proof_surfaces_required",
            set.proof_refs.visible_summary.len() >= 300
                && red_pass(&red_results, "bad_sandbox_ref")
                && red_pass(&red_results, "bad_provenance_ref")
                && red_pass(&red_results, "bad_rollback_ref")
                && red_pass(&red_results, "bad_cleanup_ref")
                && red_pass(&red_results, "bad_no_product_graph_ref")
                && red_pass(&red_results, "bad_run_event_log_ref")
                && red_pass(&red_results, "bad_answer_packet_ref")
                && red_pass(&red_results, "bad_compatibility_ref")
                && red_pass(&red_results, "bad_native_link_block_ref")
                && red_pass(&red_results, "bad_benchmark_caveat_ref")
                && red_pass(&red_results, "short_visible_summary"),
        ),
        (
            "bytes_remain_zero",
            metrics.downloaded_repo_bytes == 0
                && metrics.unpacked_repo_bytes == 0
                && metrics.written_quarantine_file_count == 0
                && metrics.copied_product_file_count == 0
                && metrics.product_dependency_count == 0
                && metrics.imported_external_crate_count == 0
                && metrics.built_external_binary_count == 0
                && metrics.native_link_probe_count == 0
                && metrics.opened_product_index_bytes == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "downloaded_repo_bytes")
                && red_pass(&red_results, "unpacked_repo_bytes")
                && red_pass(&red_results, "written_quarantine_file_count")
                && red_pass(&red_results, "copied_product_file_count")
                && red_pass(&red_results, "product_dependency_count")
                && red_pass(&red_results, "imported_external_crate_count")
                && red_pass(&red_results, "built_external_binary_count")
                && red_pass(&red_results, "native_link_probe_count")
                && red_pass(&red_results, "opened_product_index_bytes")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_model_bytes_loaded")
                && red_pass(&red_results, "provider_call"),
        ),
        (
            "no_product_graph_or_dependency",
            set.policy.no_product_graph_membership
                && set.policy.no_product_dependency_insertion
                && metrics.copied_product_file_count == 0
                && metrics.product_dependency_count == 0,
        ),
        (
            "no_native_link_runtime_or_model_bytes",
            set.policy.no_native_link_probe
                && set.policy.no_runtime_execution
                && set.policy.no_index_or_model_bytes
                && metrics.native_link_probe_count == 0
                && metrics.runtime_model_bytes_loaded == 0
                && metrics.model_bytes_loaded == 0,
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
                && red_pass(&red_results, "status_executed")
                && red_pass(&red_results, "tier_t2"),
        ),
        (
            "large_local_model_research_bias_preserved",
            set.proof_refs
                .visible_summary
                .contains("Gemma QAT and larger local model")
                && set.proof_refs.visible_summary.contains("no live dense 70B")
                && set
                    .proof_refs
                    .visible_summary
                    .contains("no route authority"),
        ),
        (
            "reversed_order_address_deterministic",
            set.set_address == reversed.set_address
                && fetch_lease_digest(&set) == fetch_lease_digest(&reversed),
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
        "phase_count",
        metrics.phase_count,
        "==",
        6,
        "phases",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "planned_download_bytes",
        metrics.planned_download_bytes,
        "==",
        PLANNED_DOWNLOAD_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "planned_unpacked_bytes",
        metrics.planned_unpacked_bytes,
        "==",
        PLANNED_UNPACKED_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_file_count",
        metrics.max_file_count,
        "==",
        2_000,
        "files",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lease_expires_after_seconds",
        metrics.lease_expires_after_seconds,
        "==",
        1_800,
        "seconds",
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
        "fetch_lease_address",
        &set.set_address.to_string(),
        "turbovec_real_adapter_fetch_lease_probe:",
        "uas_address",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        TURBOVEC_REAL_ADAPTER_FETCH_LEASE_NEXT_CURSOR,
        TURBOVEC_REAL_ADAPTER_FETCH_LEASE_NEXT_CURSOR,
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
            "kind": "metadata_only_fetch_lease_scope",
            "detail": "Pinned TurboVec source fetch lease only. No network fetch, clone, source import, product dependency, adapter build, native-link probe, index/model/runtime/provider bytes, route/context authority, or live large-local-model claim."
        })],
        notes: "Builds F-TurboVec-RealAdapterFetchLeaseProbe as a T1/L1 metadata-only lease for future bounded TurboVec source intake. It makes the large-local-model compression path more buildable by pinning the upstream identity, codeload URL, quarantine target, byte caps, cleanup/rollback proof, RunEventLog, AnswerPacket, no-product-graph audit, native-link block, and benchmark caveat before any real source bytes may be fetched by a later witness. L2 capability and L3 user-facing model surfaces remain unchanged.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_sandbox_layout_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec sandbox-layout gate has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_REAL_ADAPTER_FETCH_LEASE_CURSOR)
    {
        return Err("upstream sandbox-layout gate does not point at fetch lease".into());
    }
    for axis in [
        "/pass_per_axis/upstream_dependency_envelope_bound",
        "/pass_per_axis/sandbox_layout_slots_complete",
        "/pass_per_axis/quarantine_root_path_policy",
        "/pass_per_axis/product_and_build_roots_rejected",
        "/pass_per_axis/cleanup_and_rollback_required",
        "/pass_per_axis/proof_surfaces_required",
        "/pass_per_axis/bytes_remain_metadata_only",
        "/pass_per_axis/no_fetch_clone_import_build_or_route",
        "/pass_per_axis/no_index_model_runtime_provider_bytes",
        "/pass_per_axis/no_route_context_or_hidden_authority",
        "/pass_per_axis/product_and_large_model_claims_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(format!("upstream sandbox-layout axis missing or false: {axis}").into());
        }
    }
    let address = value
        .pointer("/measurements/sandbox_layout_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("upstream sandbox-layout address missing")?;
    Ok(UasAddress::from_str(address)?)
}

#[allow(clippy::too_many_arguments)]
fn build_set(
    upstream: UasAddress,
    source: TurboVecFetchLeaseSource,
    target: TurboVecFetchLeaseTarget,
    phases: Vec<TurboVecFetchLeasePhase>,
    policy: TurboVecFetchLeasePolicy,
    proof_refs: TurboVecFetchLeaseProofRefs,
    byte_ledger: TurboVecFetchLeaseByteLedger,
    product_build: ProductBuild,
    pro_status: ProStatus,
    status: TurboVecFetchLeaseStatus,
    promotion_tier: TurboVecFetchLeaseTier,
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<TurboVecRealAdapterFetchLeaseProbeSet, Box<dyn std::error::Error>> {
    Ok(TurboVecRealAdapterFetchLeaseProbeSet::from_parts(
        upstream,
        source,
        target,
        phases,
        policy,
        proof_refs,
        byte_ledger,
        product_build,
        pro_status,
        status,
        promotion_tier,
        organs(),
        LEASE_METADATA_BYTES,
        product_capability_promoted,
        route_mutation_allowed,
        model_context_injected,
        hidden_route_authority,
        hidden_cloud_fallback_allowed,
        live_large_model_claimed,
        ssd_as_ram_claimed,
    )?)
}

fn source() -> TurboVecFetchLeaseSource {
    TurboVecFetchLeaseSource {
        source_ref: format!("source:turbovec-fetch-lease:{PINNED_REVISION}"),
        source_url: SOURCE_URL.to_string(),
        clone_url: CLONE_URL.to_string(),
        fetch_url: format!("{FETCH_URL_PREFIX}{PINNED_REVISION}"),
        pinned_revision: PINNED_REVISION.to_string(),
        current_head_revision: PINNED_REVISION.to_string(),
        license_ref: format!("license:turbovec:mit:{PINNED_REVISION}"),
        commit_ref: format!("github_commit:turbovec:{PINNED_REVISION}"),
        transport: TurboVecFetchTransport::GitHubCodeloadTarball,
    }
}

fn target() -> TurboVecFetchLeaseTarget {
    TurboVecFetchLeaseTarget {
        quarantine_root: QUARANTINE_ROOT.to_string(),
        source_tree_path: format!("{QUARANTINE_ROOT}/source-tree"),
        temp_download_path: format!("{QUARANTINE_ROOT}/source-tree.tmp"),
        source_manifest_path: format!("{QUARANTINE_ROOT}/source-manifest.json"),
        cleanup_tombstone_path: format!("{QUARANTINE_ROOT}/cleanup-tombstones/fetch-lease"),
    }
}

fn phases() -> Vec<TurboVecFetchLeasePhase> {
    vec![
        TurboVecFetchLeasePhase::LeaseDeclaration,
        TurboVecFetchLeasePhase::OwnerApprovalPending,
        TurboVecFetchLeasePhase::ByteCapPreflight,
        TurboVecFetchLeasePhase::NoProductGraphAudit,
        TurboVecFetchLeasePhase::CleanupReplay,
        TurboVecFetchLeasePhase::AnswerPacketDryRun,
    ]
}

fn policy() -> TurboVecFetchLeasePolicy {
    TurboVecFetchLeasePolicy::fail_closed()
}

fn proof_refs() -> TurboVecFetchLeaseProofRefs {
    TurboVecFetchLeaseProofRefs {
        sandbox_layout_ref: "artifact:turbovec_real_adapter_sandbox_layout_probe:result"
            .to_string(),
        provenance_ref: "provenance:turbovec-fetch-lease:github-codeload-clean-room-source-card"
            .to_string(),
        rollback_ref: "rollback:turbovec-fetch-lease:delete-quarantine-source-tree".to_string(),
        cleanup_ref: "cleanup:turbovec-fetch-lease:expiry-and-tombstone-replay".to_string(),
        no_product_graph_ref: "no_product_graph:turbovec-fetch-lease:cargo-build-route-excluded"
            .to_string(),
        run_event_log_ref: "run_event_log:turbovec-fetch-lease:metadata-only-dry-run"
            .to_string(),
        answer_packet_ref: "answer_packet:turbovec-fetch-lease:visible-fetch-not-executed"
            .to_string(),
        compatibility_fence_ref: "compat:turbovec-fetch-lease:mas-pro-source-exclusion"
            .to_string(),
        native_link_block_ref: "native_link:turbovec-fetch-lease:blocked-until-source-manifest"
            .to_string(),
        benchmark_caveat_ref: "benchmark_caveat:turbovec-fetch-lease:no-speed-quality-claim"
            .to_string(),
        visible_summary: "This fetch lease preserves the large-local-model research path for TurboVec, TurboQuant, Gemma QAT and larger local model context selection by declaring a future bounded source archive fetch into quarantine only. Owner approval is pending, network fetch is not allowed by this witness, product graphs and dependencies stay excluded, cleanup replay and AnswerPacket proof are required, native-link/build/runtime actions remain blocked, no model/index/runtime/provider bytes are loaded, no route authority is granted, there is no hidden cloud fallback, no live dense 70B claim, and no SSD-as-RAM claim.".to_string(),
    }
}

fn byte_ledger() -> TurboVecFetchLeaseByteLedger {
    TurboVecFetchLeaseByteLedger::metadata_only(
        LEASE_METADATA_BYTES,
        PLANNED_DOWNLOAD_BYTES,
        PLANNED_UNPACKED_BYTES,
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

fn red_fixture_results(upstream: &UasAddress) -> Vec<(String, bool)> {
    let mut results = Vec::new();

    push_case(&mut results, "bad_upstream_cursor", || {
        let bad = UasAddress::from_str(
            "wrong_turbovec_gate:f59dcce8a5c6691d3cf9c132f99e80c44a42b85c784d9b49745d1d435d26d2f5@1779040900000",
        );
        match bad {
            Ok(address) => default_with_upstream(address).is_err(),
            Err(_) => true,
        }
    });

    for (name, field) in [
        ("bad_source_ref", SourceField::SourceRef),
        ("bad_source_url", SourceField::SourceUrl),
        ("bad_clone_url", SourceField::CloneUrl),
        ("bad_fetch_url_prefix", SourceField::FetchUrlPrefix),
        ("bad_fetch_url_revision", SourceField::FetchUrlRevision),
        ("bad_pinned_revision", SourceField::PinnedRevision),
        ("bad_current_head", SourceField::CurrentHead),
        ("bad_license_ref", SourceField::LicenseRef),
        ("bad_commit_ref", SourceField::CommitRef),
    ] {
        push_case(&mut results, name, || {
            let mut source = source();
            mutate_source(&mut source, field);
            default_with_source(upstream.clone(), source).is_err()
        });
    }

    for (name, transport) in [
        ("git_clone_transport", TurboVecFetchTransport::GitHttpsClone),
        ("ssh_clone_transport", TurboVecFetchTransport::SshClone),
        (
            "local_copy_transport",
            TurboVecFetchTransport::LocalPathCopy,
        ),
        (
            "registry_transport",
            TurboVecFetchTransport::PackageRegistry,
        ),
    ] {
        push_case(&mut results, name, || {
            let mut source = source();
            source.transport = transport;
            default_with_source(upstream.clone(), source).is_err()
        });
    }

    for (name, field, path) in [
        (
            "absolute_target_path",
            TargetField::SourceTree,
            "/tmp/turbovec/source-tree",
        ),
        (
            "traversal_target_path",
            TargetField::SourceTree,
            ".epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2/../agent_core",
        ),
        ("empty_target_path", TargetField::SourceTree, ""),
        (
            "dot_target_path",
            TargetField::SourceTree,
            ".epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2/./source-tree",
        ),
        (
            "double_slash_target_path",
            TargetField::SourceTree,
            ".epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2//source-tree",
        ),
        (
            "backslash_target_path",
            TargetField::SourceTree,
            ".epistemos-quarantine\\turbovec\\source-tree",
        ),
        (
            "outside_quarantine_root",
            TargetField::SourceTree,
            ".epistemos-quarantine/other/source-tree",
        ),
        (
            "product_path_agent_core",
            TargetField::SourceTree,
            "agent_core/src/uas/turbovec.rs",
        ),
        (
            "product_path_epistemos",
            TargetField::SourceTree,
            "Epistemos/Engine/TurboVec.swift",
        ),
        (
            "product_path_graph_engine",
            TargetField::SourceTree,
            "graph-engine/src/turbovec.rs",
        ),
        (
            "product_path_tools",
            TargetField::SourceTree,
            "Tools/falsifiers/f_turbovec.sh",
        ),
        (
            "product_path_docs",
            TargetField::SourceTree,
            "docs/fusion/turbovec.md",
        ),
        (
            "product_path_artifacts_falsifiers",
            TargetField::SourceTree,
            "artifacts/falsifiers/turbovec/result.json",
        ),
        (
            "product_path_benchmarks",
            TargetField::SourceTree,
            "benchmarks/results/turbovec.json",
        ),
        (
            "product_path_target",
            TargetField::SourceTree,
            "target/debug/turbovec",
        ),
        (
            "product_path_git",
            TargetField::SourceTree,
            ".git/modules/turbovec",
        ),
    ] {
        push_case(&mut results, name, || {
            let mut target = target();
            mutate_target(&mut target, field, path);
            default_with_target(upstream.clone(), target).is_err()
        });
    }

    push_case(&mut results, "duplicate_target_path", || {
        let mut target = target();
        target.temp_download_path = target.source_tree_path.clone();
        default_with_target(upstream.clone(), target).is_err()
    });
    push_case(&mut results, "bad_quarantine_root", || {
        let mut target = target();
        target.quarantine_root = ".epistemos-quarantine/turbovec/wrong".to_string();
        default_with_target(upstream.clone(), target).is_err()
    });

    for (name, phase) in [
        (
            "missing_lease_declaration_phase",
            TurboVecFetchLeasePhase::LeaseDeclaration,
        ),
        (
            "missing_owner_approval_phase",
            TurboVecFetchLeasePhase::OwnerApprovalPending,
        ),
        (
            "missing_byte_cap_phase",
            TurboVecFetchLeasePhase::ByteCapPreflight,
        ),
        (
            "missing_no_product_graph_phase",
            TurboVecFetchLeasePhase::NoProductGraphAudit,
        ),
        (
            "missing_cleanup_phase",
            TurboVecFetchLeasePhase::CleanupReplay,
        ),
        (
            "missing_answer_packet_phase",
            TurboVecFetchLeasePhase::AnswerPacketDryRun,
        ),
    ] {
        push_case(&mut results, name, || {
            let phases: Vec<_> = phases()
                .into_iter()
                .filter(|candidate| candidate != &phase)
                .collect();
            default_with_phases(upstream.clone(), phases).is_err()
        });
    }
    push_case(&mut results, "duplicate_phase", || {
        let mut phases = phases();
        phases.push(TurboVecFetchLeasePhase::LeaseDeclaration);
        default_with_phases(upstream.clone(), phases).is_err()
    });

    for (name, mutation) in [
        (
            "owner_approval_not_required",
            PolicyMutation::OwnerApprovalNotRequired,
        ),
        (
            "owner_approval_granted",
            PolicyMutation::OwnerApprovalGranted,
        ),
        (
            "network_fetch_allowed_now",
            PolicyMutation::NetworkFetchAllowed,
        ),
        (
            "later_witness_not_required",
            PolicyMutation::LaterWitnessNotRequired,
        ),
        (
            "source_manifest_not_required",
            PolicyMutation::SourceManifestNotRequired,
        ),
        (
            "product_graph_membership_allowed",
            PolicyMutation::ProductGraphAllowed,
        ),
        (
            "product_dependency_allowed",
            PolicyMutation::ProductDependencyAllowed,
        ),
        ("native_link_allowed", PolicyMutation::NativeLinkAllowed),
        ("runtime_allowed", PolicyMutation::RuntimeAllowed),
        (
            "index_or_model_bytes_allowed",
            PolicyMutation::IndexOrModelAllowed,
        ),
        ("cleanup_not_required", PolicyMutation::CleanupNotRequired),
        (
            "answer_packet_not_required",
            PolicyMutation::AnswerPacketNotRequired,
        ),
        ("download_cap_zero", PolicyMutation::DownloadCapZero),
        ("download_cap_over", PolicyMutation::DownloadCapOver),
        ("unpacked_cap_below", PolicyMutation::UnpackedCapBelow),
        ("unpacked_cap_over", PolicyMutation::UnpackedCapOver),
        ("file_count_zero", PolicyMutation::FileCountZero),
        ("file_count_over", PolicyMutation::FileCountOver),
        ("expiry_zero", PolicyMutation::ExpiryZero),
        ("expiry_over", PolicyMutation::ExpiryOver),
        (
            "fetch_archive_action",
            PolicyMutation::Action(TurboVecFetchLeaseAction::FetchArchiveByLaterWitness),
        ),
        (
            "git_clone_action",
            PolicyMutation::Action(TurboVecFetchLeaseAction::GitCloneByLaterWitness),
        ),
        (
            "copy_product_action",
            PolicyMutation::Action(TurboVecFetchLeaseAction::CopyIntoProduct),
        ),
        (
            "add_dependency_action",
            PolicyMutation::Action(TurboVecFetchLeaseAction::AddProductDependency),
        ),
        (
            "build_adapter_action",
            PolicyMutation::Action(TurboVecFetchLeaseAction::BuildAdapter),
        ),
        (
            "native_link_action",
            PolicyMutation::Action(TurboVecFetchLeaseAction::NativeLinkProbe),
        ),
        (
            "runtime_route_action",
            PolicyMutation::Action(TurboVecFetchLeaseAction::RuntimeRoute),
        ),
    ] {
        push_case(&mut results, name, || {
            let mut policy = policy();
            mutate_policy(&mut policy, mutation);
            default_with_policy(upstream.clone(), policy).is_err()
        });
    }

    for (name, field) in [
        ("bad_sandbox_ref", ProofField::Sandbox),
        ("bad_provenance_ref", ProofField::Provenance),
        ("bad_rollback_ref", ProofField::Rollback),
        ("bad_cleanup_ref", ProofField::Cleanup),
        ("bad_no_product_graph_ref", ProofField::NoProductGraph),
        ("bad_run_event_log_ref", ProofField::RunEventLog),
        ("bad_answer_packet_ref", ProofField::AnswerPacket),
        ("bad_compatibility_ref", ProofField::Compatibility),
        ("bad_native_link_block_ref", ProofField::NativeLinkBlock),
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
        (
            "metadata_budget_exceeded",
            ByteMutation::MetadataBudgetExceeded,
        ),
        (
            "ledger_metadata_mismatch",
            ByteMutation::LedgerMetadataMismatch,
        ),
        ("planned_download_zero", ByteMutation::PlannedDownloadZero),
        ("planned_download_over", ByteMutation::PlannedDownloadOver),
        ("planned_unpacked_below", ByteMutation::PlannedUnpackedBelow),
        ("planned_unpacked_over", ByteMutation::PlannedUnpackedOver),
        ("downloaded_repo_bytes", ByteMutation::DownloadedRepoBytes),
        ("unpacked_repo_bytes", ByteMutation::UnpackedRepoBytes),
        (
            "written_quarantine_file_count",
            ByteMutation::WrittenQuarantineFile,
        ),
        ("copied_product_file_count", ByteMutation::CopiedProductFile),
        ("product_dependency_count", ByteMutation::ProductDependency),
        (
            "imported_external_crate_count",
            ByteMutation::ImportedExternalCrate,
        ),
        (
            "built_external_binary_count",
            ByteMutation::BuiltExternalBinary,
        ),
        ("native_link_probe_count", ByteMutation::NativeLinkProbe),
        (
            "opened_product_index_bytes",
            ByteMutation::OpenedProductIndex,
        ),
        ("model_bytes_loaded", ByteMutation::ModelBytesLoaded),
        (
            "runtime_model_bytes_loaded",
            ByteMutation::RuntimeModelBytesLoaded,
        ),
        ("provider_call", ByteMutation::ProviderCall),
    ] {
        push_case(&mut results, name, || {
            let mut ledger = byte_ledger();
            let mut metadata_bytes = LEASE_METADATA_BYTES;
            mutate_ledger(&mut ledger, &mut metadata_bytes, mutation);
            build_set_with_metadata(upstream.clone(), ledger, metadata_bytes).is_err()
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

    push_case(&mut results, "product_build_mas", || {
        build_set(
            upstream.clone(),
            source(),
            target(),
            phases(),
            policy(),
            proof_refs(),
            byte_ledger(),
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            TurboVecFetchLeaseStatus::MetadataOnlyLease,
            TurboVecFetchLeaseTier::T1L1Metadata,
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
    push_case(&mut results, "pro_status_live", || {
        build_set(
            upstream.clone(),
            source(),
            target(),
            phases(),
            policy(),
            proof_refs(),
            byte_ledger(),
            ProductBuild::Pro,
            ProStatus::Live,
            TurboVecFetchLeaseStatus::MetadataOnlyLease,
            TurboVecFetchLeaseTier::T1L1Metadata,
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
    push_case(&mut results, "status_executed", || {
        build_set(
            upstream.clone(),
            source(),
            target(),
            phases(),
            policy(),
            proof_refs(),
            byte_ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecFetchLeaseStatus::ExecutedByLaterWitness,
            TurboVecFetchLeaseTier::T1L1Metadata,
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
    push_case(&mut results, "tier_t2", || {
        build_set(
            upstream.clone(),
            source(),
            target(),
            phases(),
            policy(),
            proof_refs(),
            byte_ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecFetchLeaseStatus::MetadataOnlyLease,
            TurboVecFetchLeaseTier::T2L2Route,
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
    push_case(&mut results, "duplicate_organ", || {
        let mut organs = organs();
        organs.push(TurboVecIndexOrgan::Eidos);
        TurboVecRealAdapterFetchLeaseProbeSet::from_parts(
            upstream.clone(),
            source(),
            target(),
            phases(),
            policy(),
            proof_refs(),
            byte_ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecFetchLeaseStatus::MetadataOnlyLease,
            TurboVecFetchLeaseTier::T1L1Metadata,
            organs,
            LEASE_METADATA_BYTES,
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

    results
}

fn default_with_upstream(
    upstream: UasAddress,
) -> Result<TurboVecRealAdapterFetchLeaseProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        source(),
        target(),
        phases(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecFetchLeaseStatus::MetadataOnlyLease,
        TurboVecFetchLeaseTier::T1L1Metadata,
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
    source: TurboVecFetchLeaseSource,
) -> Result<TurboVecRealAdapterFetchLeaseProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        source,
        target(),
        phases(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecFetchLeaseStatus::MetadataOnlyLease,
        TurboVecFetchLeaseTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn default_with_target(
    upstream: UasAddress,
    target: TurboVecFetchLeaseTarget,
) -> Result<TurboVecRealAdapterFetchLeaseProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        source(),
        target,
        phases(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecFetchLeaseStatus::MetadataOnlyLease,
        TurboVecFetchLeaseTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn default_with_phases(
    upstream: UasAddress,
    phases: Vec<TurboVecFetchLeasePhase>,
) -> Result<TurboVecRealAdapterFetchLeaseProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        source(),
        target(),
        phases,
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecFetchLeaseStatus::MetadataOnlyLease,
        TurboVecFetchLeaseTier::T1L1Metadata,
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
    policy: TurboVecFetchLeasePolicy,
) -> Result<TurboVecRealAdapterFetchLeaseProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        source(),
        target(),
        phases(),
        policy,
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecFetchLeaseStatus::MetadataOnlyLease,
        TurboVecFetchLeaseTier::T1L1Metadata,
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
    proof_refs: TurboVecFetchLeaseProofRefs,
) -> Result<TurboVecRealAdapterFetchLeaseProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        source(),
        target(),
        phases(),
        policy(),
        proof_refs,
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecFetchLeaseStatus::MetadataOnlyLease,
        TurboVecFetchLeaseTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn build_set_with_metadata(
    upstream: UasAddress,
    byte_ledger: TurboVecFetchLeaseByteLedger,
    metadata_bytes: u64,
) -> Result<TurboVecRealAdapterFetchLeaseProbeSet, Box<dyn std::error::Error>> {
    Ok(TurboVecRealAdapterFetchLeaseProbeSet::from_parts(
        upstream,
        source(),
        target(),
        phases(),
        policy(),
        proof_refs(),
        byte_ledger,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecFetchLeaseStatus::MetadataOnlyLease,
        TurboVecFetchLeaseTier::T1L1Metadata,
        organs(),
        metadata_bytes,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )?)
}

fn default_with_claim_flag(
    upstream: UasAddress,
    flag: ClaimFlag,
) -> Result<TurboVecRealAdapterFetchLeaseProbeSet, Box<dyn std::error::Error>> {
    let product_capability_promoted = matches!(flag, ClaimFlag::ProductPromoted);
    let route_mutation_allowed = matches!(flag, ClaimFlag::RouteMutation);
    let model_context_injected = matches!(flag, ClaimFlag::ContextInjection);
    let hidden_route_authority = matches!(flag, ClaimFlag::HiddenAuthority);
    let hidden_cloud_fallback_allowed = matches!(flag, ClaimFlag::HiddenCloud);
    let live_large_model_claimed = matches!(flag, ClaimFlag::LiveLargeModel);
    let ssd_as_ram_claimed = matches!(flag, ClaimFlag::SsdAsRam);
    build_set(
        upstream,
        source(),
        target(),
        phases(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecFetchLeaseStatus::MetadataOnlyLease,
        TurboVecFetchLeaseTier::T1L1Metadata,
        product_capability_promoted,
        route_mutation_allowed,
        model_context_injected,
        hidden_route_authority,
        hidden_cloud_fallback_allowed,
        live_large_model_claimed,
        ssd_as_ram_claimed,
    )
}

fn mutate_source(source: &mut TurboVecFetchLeaseSource, field: SourceField) {
    match field {
        SourceField::SourceRef => source.source_ref = "source:wrong".to_string(),
        SourceField::SourceUrl => source.source_url = "https://github.com/other/turbovec".to_string(),
        SourceField::CloneUrl => {
            source.clone_url = "git@github.com:RyanCodrai/turbovec.git".to_string()
        }
        SourceField::FetchUrlPrefix => {
            source.fetch_url =
                format!("https://github.com/RyanCodrai/turbovec/archive/{PINNED_REVISION}.tar.gz")
        }
        SourceField::FetchUrlRevision => {
            source.fetch_url =
                "https://codeload.github.com/RyanCodrai/turbovec/tar.gz/0000000000000000000000000000000000000000".to_string()
        }
        SourceField::PinnedRevision => {
            source.pinned_revision = "EFE29A184986CBF562A9847C2AC52A2990BFACA2".to_string()
        }
        SourceField::CurrentHead => {
            source.current_head_revision = "0000000000000000000000000000000000000000".to_string()
        }
        SourceField::LicenseRef => source.license_ref = "license:turbovec:none".to_string(),
        SourceField::CommitRef => source.commit_ref = "commit:turbovec:short".to_string(),
    }
}

fn mutate_target(target: &mut TurboVecFetchLeaseTarget, field: TargetField, value: &str) {
    match field {
        TargetField::SourceTree => target.source_tree_path = value.to_string(),
    }
}

fn mutate_policy(policy: &mut TurboVecFetchLeasePolicy, mutation: PolicyMutation) {
    match mutation {
        PolicyMutation::OwnerApprovalNotRequired => policy.owner_approval_required = false,
        PolicyMutation::OwnerApprovalGranted => policy.owner_approval_granted = true,
        PolicyMutation::NetworkFetchAllowed => policy.network_fetch_allowed_now = true,
        PolicyMutation::LaterWitnessNotRequired => {
            policy.future_fetch_requires_later_witness = false
        }
        PolicyMutation::SourceManifestNotRequired => {
            policy.source_byte_manifest_required_after_fetch = false
        }
        PolicyMutation::ProductGraphAllowed => policy.no_product_graph_membership = false,
        PolicyMutation::ProductDependencyAllowed => policy.no_product_dependency_insertion = false,
        PolicyMutation::NativeLinkAllowed => policy.no_native_link_probe = false,
        PolicyMutation::RuntimeAllowed => policy.no_runtime_execution = false,
        PolicyMutation::IndexOrModelAllowed => policy.no_index_or_model_bytes = false,
        PolicyMutation::CleanupNotRequired => policy.cleanup_replay_required = false,
        PolicyMutation::AnswerPacketNotRequired => policy.answer_packet_required = false,
        PolicyMutation::DownloadCapZero => policy.max_download_bytes = 0,
        PolicyMutation::DownloadCapOver => policy.max_download_bytes = PLANNED_DOWNLOAD_BYTES + 1,
        PolicyMutation::UnpackedCapBelow => {
            policy.max_unpacked_bytes = policy.max_download_bytes - 1
        }
        PolicyMutation::UnpackedCapOver => policy.max_unpacked_bytes = PLANNED_UNPACKED_BYTES + 1,
        PolicyMutation::FileCountZero => policy.max_file_count = 0,
        PolicyMutation::FileCountOver => policy.max_file_count = 2_001,
        PolicyMutation::ExpiryZero => policy.lease_expires_after_seconds = 0,
        PolicyMutation::ExpiryOver => policy.lease_expires_after_seconds = 1_801,
        PolicyMutation::Action(action) => policy.allowed_action = action,
    }
}

fn mutate_proof(refs: &mut TurboVecFetchLeaseProofRefs, field: ProofField) {
    match field {
        ProofField::Sandbox => refs.sandbox_layout_ref = "artifact:wrong:result".to_string(),
        ProofField::Provenance => refs.provenance_ref = "bad:provenance".to_string(),
        ProofField::Rollback => refs.rollback_ref = "bad:rollback".to_string(),
        ProofField::Cleanup => refs.cleanup_ref = "bad:cleanup".to_string(),
        ProofField::NoProductGraph => refs.no_product_graph_ref = "bad:graph".to_string(),
        ProofField::RunEventLog => refs.run_event_log_ref = "bad:log".to_string(),
        ProofField::AnswerPacket => refs.answer_packet_ref = "bad:answer".to_string(),
        ProofField::Compatibility => refs.compatibility_fence_ref = "bad:compat".to_string(),
        ProofField::NativeLinkBlock => refs.native_link_block_ref = "bad:native".to_string(),
        ProofField::BenchmarkCaveat => refs.benchmark_caveat_ref = "bad:bench".to_string(),
        ProofField::VisibleSummary => refs.visible_summary = "too short".to_string(),
    }
}

fn mutate_ledger(
    ledger: &mut TurboVecFetchLeaseByteLedger,
    metadata_bytes: &mut u64,
    mutation: ByteMutation,
) {
    match mutation {
        ByteMutation::MetadataBudgetExceeded => {
            ledger.lease_metadata_bytes_read = 3 * 1024 * 1024;
            *metadata_bytes = 3 * 1024 * 1024;
        }
        ByteMutation::LedgerMetadataMismatch => ledger.lease_metadata_bytes_read = 1,
        ByteMutation::PlannedDownloadZero => ledger.planned_download_bytes = 0,
        ByteMutation::PlannedDownloadOver => {
            ledger.planned_download_bytes = PLANNED_DOWNLOAD_BYTES + 1
        }
        ByteMutation::PlannedUnpackedBelow => {
            ledger.planned_unpacked_bytes = ledger.planned_download_bytes - 1
        }
        ByteMutation::PlannedUnpackedOver => {
            ledger.planned_unpacked_bytes = PLANNED_UNPACKED_BYTES + 1
        }
        ByteMutation::DownloadedRepoBytes => ledger.downloaded_repo_bytes = 1,
        ByteMutation::UnpackedRepoBytes => ledger.unpacked_repo_bytes = 1,
        ByteMutation::WrittenQuarantineFile => ledger.written_quarantine_file_count = 1,
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
    CloneUrl,
    FetchUrlPrefix,
    FetchUrlRevision,
    PinnedRevision,
    CurrentHead,
    LicenseRef,
    CommitRef,
}

#[derive(Clone, Copy)]
// UAS-EXEMPT: local red-fixture mutation helper for this falsifier binary.
enum TargetField {
    SourceTree,
}

#[derive(Clone, Copy)]
// UAS-EXEMPT: local red-fixture mutation helper for this falsifier binary.
enum PolicyMutation {
    OwnerApprovalNotRequired,
    OwnerApprovalGranted,
    NetworkFetchAllowed,
    LaterWitnessNotRequired,
    SourceManifestNotRequired,
    ProductGraphAllowed,
    ProductDependencyAllowed,
    NativeLinkAllowed,
    RuntimeAllowed,
    IndexOrModelAllowed,
    CleanupNotRequired,
    AnswerPacketNotRequired,
    DownloadCapZero,
    DownloadCapOver,
    UnpackedCapBelow,
    UnpackedCapOver,
    FileCountZero,
    FileCountOver,
    ExpiryZero,
    ExpiryOver,
    Action(TurboVecFetchLeaseAction),
}

#[derive(Clone, Copy)]
// UAS-EXEMPT: local red-fixture mutation helper for this falsifier binary.
enum ProofField {
    Sandbox,
    Provenance,
    Rollback,
    Cleanup,
    NoProductGraph,
    RunEventLog,
    AnswerPacket,
    Compatibility,
    NativeLinkBlock,
    BenchmarkCaveat,
    VisibleSummary,
}

#[derive(Clone, Copy)]
// UAS-EXEMPT: local red-fixture mutation helper for this falsifier binary.
enum ByteMutation {
    MetadataBudgetExceeded,
    LedgerMetadataMismatch,
    PlannedDownloadZero,
    PlannedDownloadOver,
    PlannedUnpackedBelow,
    PlannedUnpackedOver,
    DownloadedRepoBytes,
    UnpackedRepoBytes,
    WrittenQuarantineFile,
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
