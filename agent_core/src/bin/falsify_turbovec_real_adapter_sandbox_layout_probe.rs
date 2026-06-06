//! `falsify_turbovec_real_adapter_sandbox_layout_probe`
//!
//! Metadata-only witness for `F-TurboVec-RealAdapterSandboxLayoutProbe`.
//! It proves the quarantine sandbox layout for future real TurboVec adapter
//! research while forbidding fetch/clone/import/build/native-link/runtime
//! activity, product dependency insertion, route/context mutation, model bytes,
//! provider calls, and large-local-model product claims.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, TurboVecIndexOrgan, TurboVecRealAdapterSandboxLayoutProbeSet,
    TurboVecSandboxByteLedger, TurboVecSandboxCleanupLedger, TurboVecSandboxCleanupPhase,
    TurboVecSandboxLayoutAction, TurboVecSandboxLayoutStatus, TurboVecSandboxLayoutTier,
    TurboVecSandboxPathPolicy, TurboVecSandboxProofRefs, TurboVecSandboxSlot,
    TurboVecSandboxSlotKind, UasAddress, TURBOVEC_REAL_ADAPTER_SANDBOX_LAYOUT_CURSOR,
    TURBOVEC_REAL_ADAPTER_SANDBOX_LAYOUT_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RealAdapterSandboxLayoutProbe";
const FIXTURE_ID: &str = "turbovec_real_adapter_sandbox_layout_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_real_adapter_sandbox_layout_probe.sh";
const RESULT: &str = "artifacts/falsifiers/turbovec_real_adapter_sandbox_layout_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_dependency_envelope_probe/result.json";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const QUARANTINE_ROOT: &str =
    ".epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2";
const LAYOUT_METADATA_BYTES: u64 = 96_000;
const PLANNED_QUARANTINE_BYTES: u64 = 8 * 1024 * 1024;
const RED_FIXTURE_FLOOR: u64 = 70;

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
        "{FALSIFIER_ID}: overall_pass={} slots={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["layout_slot_count"].value,
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
    let upstream = upstream_dependency_envelope_address()?;
    let set = build_set(
        upstream.clone(),
        accepted_slots(),
        cleanup_ledger(),
        proof_refs(),
        byte_ledger(),
        policy(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSandboxLayoutStatus::MetadataOnly,
        TurboVecSandboxLayoutTier::T1L1Metadata,
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
        accepted_slots().into_iter().rev().collect(),
        cleanup_ledger(),
        proof_refs(),
        byte_ledger(),
        policy(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSandboxLayoutStatus::MetadataOnly,
        TurboVecSandboxLayoutTier::T1L1Metadata,
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
            "upstream_dependency_envelope_bound",
            set.upstream_dependency_envelope_witness_ref
                == "artifact:turbovec_real_adapter_dependency_envelope_probe:result"
                && set
                    .upstream_dependency_envelope_address
                    .to_string()
                    .starts_with("turbovec_real_adapter_dependency_envelope_probe:")
                && red_pass(&red_results, "bad_upstream_cursor"),
        ),
        (
            "sandbox_layout_slots_complete",
            metrics.layout_slot_count == 10
                && metrics.unique_slot_path_count == 10
                && red_pass(&red_results, "missing_source_tree_slot")
                && red_pass(&red_results, "missing_fork_sweep_slot")
                && red_pass(&red_results, "missing_manifest_slot")
                && red_pass(&red_results, "missing_api_notes_slot")
                && red_pass(&red_results, "missing_test_specs_slot")
                && red_pass(&red_results, "missing_benchmark_slot")
                && red_pass(&red_results, "missing_failure_reports_slot")
                && red_pass(&red_results, "missing_clean_room_slot")
                && red_pass(&red_results, "missing_native_link_slot")
                && red_pass(&red_results, "missing_cleanup_slot")
                && red_pass(&red_results, "duplicate_slot_id")
                && red_pass(&red_results, "duplicate_slot_path"),
        ),
        (
            "quarantine_root_path_policy",
            set.policy.quarantine_root == QUARANTINE_ROOT
                && set.policy.reject_absolute_paths
                && set.policy.reject_traversal
                && set.policy.reject_symlink_slots
                && set.policy.reject_executable_slots
                && set.policy.reject_product_writable_slots
                && set.policy.deny_build_graph_membership
                && set.policy.deny_runtime_route_membership
                && red_pass(&red_results, "absolute_slot_path")
                && red_pass(&red_results, "traversal_slot_path")
                && red_pass(&red_results, "empty_slot_path")
                && red_pass(&red_results, "dot_slot_path")
                && red_pass(&red_results, "double_slash_slot_path")
                && red_pass(&red_results, "backslash_slot_path")
                && red_pass(&red_results, "outside_quarantine_root"),
        ),
        (
            "product_and_build_roots_rejected",
            metrics.forbidden_root_count >= 10
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
            "slot_mutation_actions_rejected",
            red_pass(&red_results, "slot_not_read_only")
                && red_pass(&red_results, "slot_symlink_allowed")
                && red_pass(&red_results, "slot_executable_allowed")
                && red_pass(&red_results, "slot_writes_product_path")
                && red_pass(&red_results, "slot_build_graph_member")
                && red_pass(&red_results, "slot_runtime_route_member")
                && red_pass(&red_results, "slot_fetch_action")
                && red_pass(&red_results, "slot_clone_action")
                && red_pass(&red_results, "slot_copy_product_action")
                && red_pass(&red_results, "slot_add_dependency_action")
                && red_pass(&red_results, "slot_build_adapter_action")
                && red_pass(&red_results, "slot_native_link_action")
                && red_pass(&red_results, "slot_runtime_route_action"),
        ),
        (
            "cleanup_and_rollback_required",
            metrics.cleanup_phase_count == 5
                && red_pass(&red_results, "missing_cleanup_preflight")
                && red_pass(&red_results, "missing_cleanup_fetch_expiry")
                && red_pass(&red_results, "missing_cleanup_build_scrub")
                && red_pass(&red_results, "missing_cleanup_product_audit")
                && red_pass(&red_results, "missing_cleanup_tombstone")
                && red_pass(&red_results, "duplicate_cleanup_phase")
                && red_pass(&red_results, "bad_cleanup_ref")
                && red_pass(&red_results, "bad_cleanup_tombstone")
                && red_pass(&red_results, "bad_cleanup_rollback"),
        ),
        (
            "proof_surfaces_required",
            red_pass(&red_results, "bad_dependency_envelope_ref")
                && red_pass(&red_results, "bad_provenance_ref")
                && red_pass(&red_results, "bad_rollback_ref")
                && red_pass(&red_results, "bad_run_event_log_ref")
                && red_pass(&red_results, "bad_answer_packet_ref")
                && red_pass(&red_results, "bad_compatibility_ref")
                && red_pass(&red_results, "bad_native_link_block_ref")
                && red_pass(&red_results, "bad_benchmark_caveat_ref")
                && red_pass(&red_results, "short_visible_summary"),
        ),
        (
            "bytes_remain_metadata_only",
            metrics.layout_metadata_bytes_read == LAYOUT_METADATA_BYTES
                && metrics.planned_quarantine_bytes == PLANNED_QUARANTINE_BYTES
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
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "metadata_budget_exceeded")
                && red_pass(&red_results, "ledger_metadata_mismatch"),
        ),
        (
            "no_fetch_clone_import_build_or_route",
            red_pass(&red_results, "fetched_repo_bytes")
                && red_pass(&red_results, "cloned_repo_bytes")
                && red_pass(&red_results, "copied_product_file")
                && red_pass(&red_results, "product_dependency_added")
                && red_pass(&red_results, "imported_external_crate")
                && red_pass(&red_results, "built_external_binary")
                && red_pass(&red_results, "native_link_probe"),
        ),
        (
            "no_index_model_runtime_provider_bytes",
            red_pass(&red_results, "opened_product_index")
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
            "large_local_model_research_bias_preserved",
            set.proof_refs
                .visible_summary
                .contains("no index/model/runtime/provider bytes")
                && set
                    .proof_refs
                    .visible_summary
                    .contains("no route authority")
                && set
                    .proof_refs
                    .visible_summary
                    .contains("no L2 or L3 promotion"),
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
            "layout_slot_count",
            metrics.layout_slot_count,
            10,
            "==",
            "slots",
        ),
        (
            "unique_slot_path_count",
            metrics.unique_slot_path_count,
            10,
            "==",
            "paths",
        ),
        (
            "forbidden_root_count",
            metrics.forbidden_root_count,
            10,
            ">=",
            "roots",
        ),
        (
            "cleanup_phase_count",
            metrics.cleanup_phase_count,
            5,
            "==",
            "phases",
        ),
        (
            "planned_quarantine_bytes",
            metrics.planned_quarantine_bytes,
            PLANNED_QUARANTINE_BYTES,
            "==",
            "bytes",
        ),
        (
            "layout_metadata_bytes_read",
            metrics.layout_metadata_bytes_read,
            LAYOUT_METADATA_BYTES,
            "==",
            "bytes",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            RED_FIXTURE_FLOOR,
            ">=",
            "fixtures",
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
        "sandbox_layout_address",
        &set.set_address.to_string(),
        "turbovec_real_adapter_sandbox_layout_probe:",
        "uas_address",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        TURBOVEC_REAL_ADAPTER_SANDBOX_LAYOUT_NEXT_CURSOR,
        TURBOVEC_REAL_ADAPTER_SANDBOX_LAYOUT_NEXT_CURSOR,
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
            "kind": "metadata_only_sandbox_layout_scope",
            "detail": "Pinned TurboVec adapter sandbox layout only. No repository bytes fetched or cloned, no product source copied, no dependency inserted, no adapter built, no native link probe, no index/model/runtime/provider bytes loaded, and no route/context authority granted."
        })],
        notes: "Builds F-TurboVec-RealAdapterSandboxLayoutProbe as a T1/L1 metadata-only quarantine layout for the large-local-model compression track. It proves the allowed TurboVec research slots, product-root exclusions, cleanup/tombstone phases, rollback, RunEventLog, AnswerPacket, compatibility fence, native-link block, and benchmark caveat before any real adapter bytes can enter quarantine. This keeps no-license/risky repo mining useful for APIs, tests, benchmarks, failure cases, and clean-room motifs while preventing product contamination, hidden route authority, L2/L3 capability promotion, live dense 70B claims, SSD-as-RAM claims, or hidden cloud fallback.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_dependency_envelope_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec dependency-envelope gate has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_REAL_ADAPTER_SANDBOX_LAYOUT_CURSOR)
    {
        return Err("upstream dependency-envelope gate does not point at sandbox layout".into());
    }
    for axis in [
        "/pass_per_axis/upstream_source_pin_bound",
        "/pass_per_axis/metadata_manifest_bytes_only",
        "/pass_per_axis/no_product_dependency_or_source_import",
        "/pass_per_axis/no_route_context_or_hidden_authority",
        "/pass_per_axis/product_and_large_model_claims_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(
                format!("upstream dependency-envelope axis missing or false: {axis}").into(),
            );
        }
    }
    let address = value
        .pointer("/measurements/dependency_envelope_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("upstream dependency-envelope address missing")?;
    Ok(UasAddress::from_str(address)?)
}

#[allow(clippy::too_many_arguments)]
fn build_set(
    upstream: UasAddress,
    slots: Vec<TurboVecSandboxSlot>,
    cleanup: TurboVecSandboxCleanupLedger,
    proof_refs: TurboVecSandboxProofRefs,
    byte_ledger: TurboVecSandboxByteLedger,
    policy: TurboVecSandboxPathPolicy,
    product_build: ProductBuild,
    pro_status: ProStatus,
    status: TurboVecSandboxLayoutStatus,
    promotion_tier: TurboVecSandboxLayoutTier,
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<TurboVecRealAdapterSandboxLayoutProbeSet, Box<dyn std::error::Error>> {
    Ok(TurboVecRealAdapterSandboxLayoutProbeSet::from_parts(
        upstream,
        slots,
        cleanup,
        proof_refs,
        byte_ledger,
        product_build,
        pro_status,
        status,
        promotion_tier,
        organs(),
        policy,
        LAYOUT_METADATA_BYTES,
        product_capability_promoted,
        route_mutation_allowed,
        model_context_injected,
        hidden_route_authority,
        hidden_cloud_fallback_allowed,
        live_large_model_claimed,
        ssd_as_ram_claimed,
    )?)
}

fn policy() -> TurboVecSandboxPathPolicy {
    TurboVecSandboxPathPolicy::fail_closed(QUARANTINE_ROOT)
}

fn organs() -> Vec<TurboVecIndexOrgan> {
    vec![
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ]
}

fn accepted_slots() -> Vec<TurboVecSandboxSlot> {
    vec![
        slot(
            "source_tree_snapshot",
            TurboVecSandboxSlotKind::SourceTreeSnapshot,
            "source-tree",
            "future read-only clone/snapshot root for upstream bytes after fetch lease",
        ),
        slot(
            "fork_sweep_snapshot",
            TurboVecSandboxSlotKind::ForkSweepSnapshot,
            "fork-sweep",
            "future fork comparison metadata, issues, PRs, and failure reports",
        ),
        slot(
            "manifest_snapshot",
            TurboVecSandboxSlotKind::ManifestSnapshot,
            "manifest-snapshot",
            "dependency envelope manifests and lockfile mirror for quarantine only",
        ),
        slot(
            "extracted_api_notes",
            TurboVecSandboxSlotKind::ExtractedApiNotes,
            "extracted-api-notes",
            "API shapes and adapter contracts for clean-room planning",
        ),
        slot(
            "extracted_test_specs",
            TurboVecSandboxSlotKind::ExtractedTestSpecs,
            "extracted-test-specs",
            "test fixtures and behavior specs extracted without product import",
        ),
        slot(
            "benchmark_transcripts",
            TurboVecSandboxSlotKind::BenchmarkTranscripts,
            "benchmark-transcripts",
            "quarantine benchmark transcripts with no product performance claim",
        ),
        slot(
            "failure_reports",
            TurboVecSandboxSlotKind::FailureReports,
            "failure-reports",
            "known failures, native-link risks, license caveats, and dependency drift",
        ),
        slot(
            "clean_room_rewrite_notes",
            TurboVecSandboxSlotKind::CleanRoomRewriteNotes,
            "clean-room-rewrite-notes",
            "Epistemos-owned rewrite notes and provenance split",
        ),
        slot(
            "native_link_notes",
            TurboVecSandboxSlotKind::NativeLinkNotes,
            "native-link-notes",
            "Accelerate/OpenBLAS/native-link notes, blocked until later proof",
        ),
        slot(
            "cleanup_tombstones",
            TurboVecSandboxSlotKind::CleanupTombstones,
            "cleanup-tombstones",
            "lease expiry, scrub, tombstone, and rollback records",
        ),
    ]
}

fn slot(
    slot_id: &str,
    kind: TurboVecSandboxSlotKind,
    leaf: &str,
    purpose: &str,
) -> TurboVecSandboxSlot {
    TurboVecSandboxSlot {
        slot_id: slot_id.to_string(),
        kind,
        relative_path: format!("{QUARANTINE_ROOT}/{leaf}"),
        slot_ref: format!("quarantine_slot:turbovec-sandbox:{slot_id}"),
        purpose_ref: format!("purpose:turbovec-sandbox:{slot_id}:{purpose}"),
        read_only: true,
        symlink_allowed: false,
        executable_allowed: false,
        writes_product_path: false,
        build_graph_member: false,
        runtime_route_member: false,
        allowed_action: TurboVecSandboxLayoutAction::MetadataOnly,
    }
}

fn cleanup_ledger() -> TurboVecSandboxCleanupLedger {
    TurboVecSandboxCleanupLedger {
        phases: vec![
            TurboVecSandboxCleanupPhase::PreflightSnapshot,
            TurboVecSandboxCleanupPhase::FetchLeaseExpiry,
            TurboVecSandboxCleanupPhase::BuildOutputScrub,
            TurboVecSandboxCleanupPhase::ProductGraphAudit,
            TurboVecSandboxCleanupPhase::TombstoneCommit,
        ],
        cleanup_ref: "cleanup:turbovec-sandbox:phase-ledger".to_string(),
        tombstone_ref: "cleanup:turbovec-sandbox:tombstone-ledger".to_string(),
        rollback_ref: "rollback:turbovec-sandbox:delete-quarantine-root".to_string(),
    }
}

fn proof_refs() -> TurboVecSandboxProofRefs {
    TurboVecSandboxProofRefs {
        dependency_envelope_ref: "artifact:turbovec_real_adapter_dependency_envelope_probe:result"
            .to_string(),
        provenance_ref: "provenance:turbovec-sandbox:clean-room-quarantine-boundary".to_string(),
        rollback_ref: "rollback:turbovec-sandbox:delete-quarantine-root".to_string(),
        run_event_log_ref: "run_event_log:turbovec-sandbox:layout-dry-run".to_string(),
        answer_packet_ref: "answer_packet:turbovec-sandbox:visible-no-runtime-scope".to_string(),
        compatibility_fence_ref: "compat:turbovec-sandbox:mas-pro-build-graph-exclusion"
            .to_string(),
        native_link_block_ref: "native_link:turbovec-sandbox:blocked-until-fetch-lease"
            .to_string(),
        benchmark_caveat_ref: "benchmark_caveat:turbovec-sandbox:no-speed-quality-claim"
            .to_string(),
        visible_summary: "TurboVec and adjacent compressed-index research may be studied in quarantine for APIs, tests, benchmarks, dependency shape, fork behavior, failure cases, and clean-room motifs that could help Gemma QAT and larger local model context selection. This layout proof has no fetched repository bytes, no product source copy, no dependency insertion, no native link probe, no index/model/runtime/provider bytes, no route authority, no hidden cloud fallback, no live dense 70B claim, and no L2 or L3 promotion.".to_string(),
    }
}

fn byte_ledger() -> TurboVecSandboxByteLedger {
    TurboVecSandboxByteLedger::metadata_only(LAYOUT_METADATA_BYTES, PLANNED_QUARANTINE_BYTES)
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

    for (name, kind) in [
        (
            "missing_source_tree_slot",
            TurboVecSandboxSlotKind::SourceTreeSnapshot,
        ),
        (
            "missing_fork_sweep_slot",
            TurboVecSandboxSlotKind::ForkSweepSnapshot,
        ),
        (
            "missing_manifest_slot",
            TurboVecSandboxSlotKind::ManifestSnapshot,
        ),
        (
            "missing_api_notes_slot",
            TurboVecSandboxSlotKind::ExtractedApiNotes,
        ),
        (
            "missing_test_specs_slot",
            TurboVecSandboxSlotKind::ExtractedTestSpecs,
        ),
        (
            "missing_benchmark_slot",
            TurboVecSandboxSlotKind::BenchmarkTranscripts,
        ),
        (
            "missing_failure_reports_slot",
            TurboVecSandboxSlotKind::FailureReports,
        ),
        (
            "missing_clean_room_slot",
            TurboVecSandboxSlotKind::CleanRoomRewriteNotes,
        ),
        (
            "missing_native_link_slot",
            TurboVecSandboxSlotKind::NativeLinkNotes,
        ),
        (
            "missing_cleanup_slot",
            TurboVecSandboxSlotKind::CleanupTombstones,
        ),
    ] {
        push_case(&mut results, name, || {
            let slots: Vec<_> = accepted_slots()
                .into_iter()
                .filter(|slot| slot.kind != kind)
                .collect();
            default_with_slots(upstream.clone(), slots).is_err()
        });
    }

    push_case(&mut results, "duplicate_slot_id", || {
        let mut slots = accepted_slots();
        slots[1].slot_id = slots[0].slot_id.clone();
        default_with_slots(upstream.clone(), slots).is_err()
    });
    push_case(&mut results, "duplicate_slot_path", || {
        let mut slots = accepted_slots();
        slots[1].relative_path = slots[0].relative_path.clone();
        default_with_slots(upstream.clone(), slots).is_err()
    });

    for (name, path) in [
        ("absolute_slot_path", "/tmp/turbovec/source-tree"),
        (
            "traversal_slot_path",
            ".epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2/../agent_core",
        ),
        ("empty_slot_path", ""),
        (
            "dot_slot_path",
            ".epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2/./source-tree",
        ),
        (
            "double_slash_slot_path",
            ".epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2//source-tree",
        ),
        (
            "backslash_slot_path",
            ".epistemos-quarantine\\turbovec\\source-tree",
        ),
        (
            "outside_quarantine_root",
            ".epistemos-quarantine/other/source-tree",
        ),
        ("product_path_agent_core", "agent_core/src/uas/turbovec.rs"),
        ("product_path_epistemos", "Epistemos/Engine/TurboVec.swift"),
        ("product_path_graph_engine", "graph-engine/src/turbovec.rs"),
        ("product_path_tools", "Tools/falsifiers/f_turbovec.sh"),
        ("product_path_docs", "docs/fusion/turbovec.md"),
        (
            "product_path_artifacts_falsifiers",
            "artifacts/falsifiers/turbovec/result.json",
        ),
        (
            "product_path_benchmarks",
            "benchmarks/results/turbovec.json",
        ),
        ("product_path_target", "target/debug/turbovec"),
        ("product_path_git", ".git/modules/turbovec"),
    ] {
        push_case(&mut results, name, || {
            let mut slots = accepted_slots();
            slots[0].relative_path = path.to_string();
            default_with_slots(upstream.clone(), slots).is_err()
        });
    }

    for (name, mutate) in [
        ("slot_not_read_only", SlotMutation::NotReadOnly),
        ("slot_symlink_allowed", SlotMutation::SymlinkAllowed),
        ("slot_executable_allowed", SlotMutation::ExecutableAllowed),
        ("slot_writes_product_path", SlotMutation::WritesProductPath),
        ("slot_build_graph_member", SlotMutation::BuildGraphMember),
        (
            "slot_runtime_route_member",
            SlotMutation::RuntimeRouteMember,
        ),
        (
            "slot_fetch_action",
            SlotMutation::Action(TurboVecSandboxLayoutAction::FetchQuarantineBytes),
        ),
        (
            "slot_clone_action",
            SlotMutation::Action(TurboVecSandboxLayoutAction::CloneRepo),
        ),
        (
            "slot_copy_product_action",
            SlotMutation::Action(TurboVecSandboxLayoutAction::CopyProductSource),
        ),
        (
            "slot_add_dependency_action",
            SlotMutation::Action(TurboVecSandboxLayoutAction::AddProductDependency),
        ),
        (
            "slot_build_adapter_action",
            SlotMutation::Action(TurboVecSandboxLayoutAction::BuildAdapter),
        ),
        (
            "slot_native_link_action",
            SlotMutation::Action(TurboVecSandboxLayoutAction::NativeLinkProbe),
        ),
        (
            "slot_runtime_route_action",
            SlotMutation::Action(TurboVecSandboxLayoutAction::RuntimeRoute),
        ),
    ] {
        push_case(&mut results, name, || {
            let mut slots = accepted_slots();
            apply_slot_mutation(&mut slots[0], mutate);
            default_with_slots(upstream.clone(), slots).is_err()
        });
    }

    for (name, phase) in [
        (
            "missing_cleanup_preflight",
            TurboVecSandboxCleanupPhase::PreflightSnapshot,
        ),
        (
            "missing_cleanup_fetch_expiry",
            TurboVecSandboxCleanupPhase::FetchLeaseExpiry,
        ),
        (
            "missing_cleanup_build_scrub",
            TurboVecSandboxCleanupPhase::BuildOutputScrub,
        ),
        (
            "missing_cleanup_product_audit",
            TurboVecSandboxCleanupPhase::ProductGraphAudit,
        ),
        (
            "missing_cleanup_tombstone",
            TurboVecSandboxCleanupPhase::TombstoneCommit,
        ),
    ] {
        push_case(&mut results, name, || {
            let mut cleanup = cleanup_ledger();
            cleanup.phases.retain(|candidate| candidate != &phase);
            default_with_cleanup(upstream.clone(), cleanup).is_err()
        });
    }
    push_case(&mut results, "duplicate_cleanup_phase", || {
        let mut cleanup = cleanup_ledger();
        cleanup
            .phases
            .push(TurboVecSandboxCleanupPhase::TombstoneCommit);
        default_with_cleanup(upstream.clone(), cleanup).is_err()
    });
    for (name, field) in [
        ("bad_cleanup_ref", CleanupField::CleanupRef),
        ("bad_cleanup_tombstone", CleanupField::TombstoneRef),
        ("bad_cleanup_rollback", CleanupField::RollbackRef),
    ] {
        push_case(&mut results, name, || {
            let mut cleanup = cleanup_ledger();
            match field {
                CleanupField::CleanupRef => cleanup.cleanup_ref = "bad:cleanup".to_string(),
                CleanupField::TombstoneRef => cleanup.tombstone_ref = "bad:tombstone".to_string(),
                CleanupField::RollbackRef => cleanup.rollback_ref = "bad:rollback".to_string(),
            }
            default_with_cleanup(upstream.clone(), cleanup).is_err()
        });
    }

    for (name, field) in [
        (
            "bad_dependency_envelope_ref",
            ProofField::DependencyEnvelope,
        ),
        ("bad_provenance_ref", ProofField::Provenance),
        ("bad_rollback_ref", ProofField::Rollback),
        ("bad_run_event_log_ref", ProofField::RunEventLog),
        ("bad_answer_packet_ref", ProofField::AnswerPacket),
        ("bad_compatibility_ref", ProofField::Compatibility),
        ("bad_native_link_block_ref", ProofField::NativeLinkBlock),
        ("bad_benchmark_caveat_ref", ProofField::BenchmarkCaveat),
        ("short_visible_summary", ProofField::VisibleSummary),
    ] {
        push_case(&mut results, name, || {
            let mut refs = proof_refs();
            match field {
                ProofField::DependencyEnvelope => {
                    refs.dependency_envelope_ref = "artifact:wrong:result".to_string()
                }
                ProofField::Provenance => refs.provenance_ref = "bad:provenance".to_string(),
                ProofField::Rollback => refs.rollback_ref = "bad:rollback".to_string(),
                ProofField::RunEventLog => refs.run_event_log_ref = "bad:log".to_string(),
                ProofField::AnswerPacket => refs.answer_packet_ref = "bad:answer".to_string(),
                ProofField::Compatibility => {
                    refs.compatibility_fence_ref = "bad:compat".to_string()
                }
                ProofField::NativeLinkBlock => {
                    refs.native_link_block_ref = "bad:native".to_string()
                }
                ProofField::BenchmarkCaveat => refs.benchmark_caveat_ref = "bad:bench".to_string(),
                ProofField::VisibleSummary => refs.visible_summary = "too short".to_string(),
            }
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
        ("fetched_repo_bytes", ByteMutation::FetchedRepoBytes),
        ("cloned_repo_bytes", ByteMutation::ClonedRepoBytes),
        ("copied_product_file", ByteMutation::CopiedProductFile),
        ("product_dependency_added", ByteMutation::ProductDependency),
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
            let mut metadata_bytes = LAYOUT_METADATA_BYTES;
            match mutation {
                ByteMutation::MetadataBudgetExceeded => {
                    ledger.layout_metadata_bytes_read = 3 * 1024 * 1024;
                    metadata_bytes = 3 * 1024 * 1024;
                }
                ByteMutation::LedgerMetadataMismatch => ledger.layout_metadata_bytes_read = 1,
                ByteMutation::FetchedRepoBytes => ledger.fetched_repo_bytes = 1,
                ByteMutation::ClonedRepoBytes => ledger.cloned_repo_bytes = 1,
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
            accepted_slots(),
            cleanup_ledger(),
            proof_refs(),
            byte_ledger(),
            policy(),
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            TurboVecSandboxLayoutStatus::MetadataOnly,
            TurboVecSandboxLayoutTier::T1L1Metadata,
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
            accepted_slots(),
            cleanup_ledger(),
            proof_refs(),
            byte_ledger(),
            policy(),
            ProductBuild::Pro,
            ProStatus::Live,
            TurboVecSandboxLayoutStatus::MetadataOnly,
            TurboVecSandboxLayoutTier::T1L1Metadata,
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
    push_case(&mut results, "status_runtime_approved", || {
        build_set(
            upstream.clone(),
            accepted_slots(),
            cleanup_ledger(),
            proof_refs(),
            byte_ledger(),
            policy(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSandboxLayoutStatus::RuntimeApprovedByLaterWitness,
            TurboVecSandboxLayoutTier::T1L1Metadata,
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
            accepted_slots(),
            cleanup_ledger(),
            proof_refs(),
            byte_ledger(),
            policy(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSandboxLayoutStatus::MetadataOnly,
            TurboVecSandboxLayoutTier::T2L2Route,
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

// UAS-EXEMPT: red-fixture helper local to the falsifier binary, not a substrate declaration.
#[derive(Clone, Copy)]
enum SlotMutation {
    NotReadOnly,
    SymlinkAllowed,
    ExecutableAllowed,
    WritesProductPath,
    BuildGraphMember,
    RuntimeRouteMember,
    Action(TurboVecSandboxLayoutAction),
}

// UAS-EXEMPT: red-fixture helper local to the falsifier binary, not a substrate declaration.
#[derive(Clone, Copy)]
enum CleanupField {
    CleanupRef,
    TombstoneRef,
    RollbackRef,
}

// UAS-EXEMPT: red-fixture helper local to the falsifier binary, not a substrate declaration.
#[derive(Clone, Copy)]
enum ProofField {
    DependencyEnvelope,
    Provenance,
    Rollback,
    RunEventLog,
    AnswerPacket,
    Compatibility,
    NativeLinkBlock,
    BenchmarkCaveat,
    VisibleSummary,
}

// UAS-EXEMPT: red-fixture helper local to the falsifier binary, not a substrate declaration.
#[derive(Clone, Copy)]
enum ByteMutation {
    MetadataBudgetExceeded,
    LedgerMetadataMismatch,
    FetchedRepoBytes,
    ClonedRepoBytes,
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

// UAS-EXEMPT: red-fixture helper local to the falsifier binary, not a substrate declaration.
#[derive(Clone, Copy)]
enum ClaimFlag {
    ProductPromoted,
    RouteMutation,
    ContextInjection,
    HiddenAuthority,
    HiddenCloud,
    LiveLargeModel,
    SsdAsRam,
}

fn apply_slot_mutation(slot: &mut TurboVecSandboxSlot, mutation: SlotMutation) {
    match mutation {
        SlotMutation::NotReadOnly => slot.read_only = false,
        SlotMutation::SymlinkAllowed => slot.symlink_allowed = true,
        SlotMutation::ExecutableAllowed => slot.executable_allowed = true,
        SlotMutation::WritesProductPath => slot.writes_product_path = true,
        SlotMutation::BuildGraphMember => slot.build_graph_member = true,
        SlotMutation::RuntimeRouteMember => slot.runtime_route_member = true,
        SlotMutation::Action(action) => slot.allowed_action = action,
    }
}

fn default_with_upstream(
    upstream: UasAddress,
) -> Result<TurboVecRealAdapterSandboxLayoutProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        accepted_slots(),
        cleanup_ledger(),
        proof_refs(),
        byte_ledger(),
        policy(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSandboxLayoutStatus::MetadataOnly,
        TurboVecSandboxLayoutTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn default_with_slots(
    upstream: UasAddress,
    slots: Vec<TurboVecSandboxSlot>,
) -> Result<TurboVecRealAdapterSandboxLayoutProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        slots,
        cleanup_ledger(),
        proof_refs(),
        byte_ledger(),
        policy(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSandboxLayoutStatus::MetadataOnly,
        TurboVecSandboxLayoutTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn default_with_cleanup(
    upstream: UasAddress,
    cleanup: TurboVecSandboxCleanupLedger,
) -> Result<TurboVecRealAdapterSandboxLayoutProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        accepted_slots(),
        cleanup,
        proof_refs(),
        byte_ledger(),
        policy(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSandboxLayoutStatus::MetadataOnly,
        TurboVecSandboxLayoutTier::T1L1Metadata,
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
    proof: TurboVecSandboxProofRefs,
) -> Result<TurboVecRealAdapterSandboxLayoutProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        accepted_slots(),
        cleanup_ledger(),
        proof,
        byte_ledger(),
        policy(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSandboxLayoutStatus::MetadataOnly,
        TurboVecSandboxLayoutTier::T1L1Metadata,
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
    ledger: TurboVecSandboxByteLedger,
    metadata_bytes: u64,
) -> Result<TurboVecRealAdapterSandboxLayoutProbeSet, Box<dyn std::error::Error>> {
    Ok(TurboVecRealAdapterSandboxLayoutProbeSet::from_parts(
        upstream,
        accepted_slots(),
        cleanup_ledger(),
        proof_refs(),
        ledger,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSandboxLayoutStatus::MetadataOnly,
        TurboVecSandboxLayoutTier::T1L1Metadata,
        organs(),
        policy(),
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
) -> Result<TurboVecRealAdapterSandboxLayoutProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        accepted_slots(),
        cleanup_ledger(),
        proof_refs(),
        byte_ledger(),
        policy(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSandboxLayoutStatus::MetadataOnly,
        TurboVecSandboxLayoutTier::T1L1Metadata,
        matches!(flag, ClaimFlag::ProductPromoted),
        matches!(flag, ClaimFlag::RouteMutation),
        matches!(flag, ClaimFlag::ContextInjection),
        matches!(flag, ClaimFlag::HiddenAuthority),
        matches!(flag, ClaimFlag::HiddenCloud),
        matches!(flag, ClaimFlag::LiveLargeModel),
        matches!(flag, ClaimFlag::SsdAsRam),
    )
}

fn push_case(results: &mut Vec<(String, bool)>, name: &str, case: impl FnOnce() -> bool) {
    results.push((name.to_string(), case()));
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
