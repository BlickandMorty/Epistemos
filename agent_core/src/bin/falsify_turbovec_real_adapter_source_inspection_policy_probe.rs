//! `falsify_turbovec_real_adapter_source_inspection_policy_probe`
//!
//! Metadata-only witness for `F-TurboVec-RealAdapterSourceInspectionPolicyProbe`.
//! It consumes the source-byte manifest gate and proves future TurboVec source
//! inspection must stay quarantine-bound, paraphrase/behavior-spec only,
//! clean-room noted, rollbackable, AnswerPacket-visible, and unable to import
//! product code, build native links, run benchmarks as authority, mutate routes,
//! or claim large-local-model product capability.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    source_inspection_policy_digest, ProStatus, ProductBuild, TurboVecIndexOrgan,
    TurboVecInspectionAction, TurboVecInspectionOutputMode,
    TurboVecRealAdapterSourceInspectionPolicyProbeSet, TurboVecSourceInspectionByteLedger,
    TurboVecSourceInspectionPolicy, TurboVecSourceInspectionPolicyRow,
    TurboVecSourceInspectionProofRefs, TurboVecSourceInspectionStatus,
    TurboVecSourceInspectionTier, TurboVecSourceManifestDisposition, UasAddress, UasKind,
    TURBOVEC_REAL_ADAPTER_SOURCE_INSPECTION_POLICY_CURSOR,
    TURBOVEC_REAL_ADAPTER_SOURCE_INSPECTION_POLICY_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RealAdapterSourceInspectionPolicyProbe";
const FIXTURE_ID: &str = "turbovec_real_adapter_source_inspection_policy_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_real_adapter_source_inspection_policy_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_source_inspection_policy_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_source_byte_manifest_probe/result.json";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
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
        "{FALSIFIER_ID}: overall_pass={} rows={} future_read_rows={} blocked_rows={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["policy_row_count"].value,
        artifact.measurements["future_read_row_count"].value,
        artifact.measurements["blocked_row_count"].value,
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
    let upstream = upstream_source_byte_manifest_address()?;
    let set = build_set(
        upstream.clone(),
        rows(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceInspectionStatus::PolicyOnly,
        TurboVecSourceInspectionTier::T1L1Metadata,
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
        rows().into_iter().rev().collect(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceInspectionStatus::PolicyOnly,
        TurboVecSourceInspectionTier::T1L1Metadata,
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
            "upstream_source_byte_manifest_bound",
            set.upstream_source_byte_manifest_witness_ref
                == "artifact:turbovec_real_adapter_source_byte_manifest_probe:result"
                && set
                    .upstream_source_byte_manifest_address
                    .to_string()
                    .starts_with("turbovec_real_adapter_source_byte_manifest_probe:")
                && red_pass(&red_results, "bad_upstream_cursor"),
        ),
        (
            "policy_rows_bound",
            metrics.policy_row_count == 22
                && metrics.rust_core_row_count == 4
                && metrics.test_intent_row_count == 2
                && red_pass(&red_results, "missing_docs_api")
                && red_pass(&red_results, "missing_search_rs")
                && red_pass(&red_results, "duplicate_row_path")
                && red_pass(&red_results, "absolute_path")
                && red_pass(&red_results, "traversal_path")
                && red_pass(&red_results, "product_path_agent_core"),
        ),
        (
            "future_read_and_blocked_coverage",
            metrics.future_read_row_count >= 15
                && metrics.blocked_row_count >= 6
                && metrics.native_link_blocked_row_count >= 2
                && metrics.symlink_blocked_row_count >= 1
                && metrics.binary_blocked_row_count >= 1
                && metrics.integration_blocked_row_count >= 2
                && red_pass(&red_results, "blocked_row_read_allowed")
                && red_pass(&red_results, "blocked_row_clean_room_note")
                && red_pass(&red_results, "inspectable_row_no_future_read"),
        ),
        (
            "clean_room_and_output_modes_bound",
            metrics.clean_room_note_count >= 15
                && red_pass(&red_results, "wrong_output_mode")
                && red_pass(&red_results, "action_disposition_mismatch")
                && red_pass(&red_results, "missing_answer_packet_caveat")
                && red_pass(&red_results, "verbatim_code_allowed"),
        ),
        (
            "policy_fail_closed",
            set.policy.manifest_bound
                && !set.policy.source_bytes_read_now
                && !set.policy.raw_content_read_now
                && set.policy.future_source_read_requires_owner_approval
                && set.policy.future_source_read_requires_quarantine
                && set.policy.future_source_read_requires_manifest_row
                && set.policy.verbatim_code_forbidden
                && set.policy.paraphrase_or_behavior_spec_only
                && !set.policy.product_import_allowed
                && !set.policy.product_dependency_allowed
                && !set.policy.native_link_probe_allowed
                && !set.policy.benchmark_authority_allowed
                && !set.policy.runtime_execution_allowed
                && !set.policy.route_authority_allowed
                && set.policy.clean_room_notes_required
                && set.policy.source_cards_required
                && set.policy.rollback_required
                && set.policy.answer_packet_required
                && set.policy.blocked_rows_remain_unread
                && red_pass(&red_results, "policy_not_manifest_bound")
                && red_pass(&red_results, "policy_source_bytes_now")
                && red_pass(&red_results, "policy_raw_content_now")
                && red_pass(&red_results, "policy_owner_not_required")
                && red_pass(&red_results, "policy_quarantine_not_required")
                && red_pass(&red_results, "policy_manifest_row_not_required")
                && red_pass(&red_results, "policy_verbatim_not_forbidden")
                && red_pass(&red_results, "policy_product_import")
                && red_pass(&red_results, "policy_dependency")
                && red_pass(&red_results, "policy_native_link")
                && red_pass(&red_results, "policy_benchmark_authority")
                && red_pass(&red_results, "policy_runtime")
                && red_pass(&red_results, "policy_route_authority"),
        ),
        (
            "proof_surfaces_required",
            set.proof_refs.visible_summary.len() >= 420
                && red_pass(&red_results, "bad_manifest_ref")
                && red_pass(&red_results, "bad_provenance_ref")
                && red_pass(&red_results, "bad_clean_room_ref")
                && red_pass(&red_results, "bad_source_card_ref")
                && red_pass(&red_results, "bad_fork_sweep_ref")
                && red_pass(&red_results, "bad_no_product_graph_ref")
                && red_pass(&red_results, "bad_rollback_ref")
                && red_pass(&red_results, "bad_run_event_log_ref")
                && red_pass(&red_results, "bad_answer_packet_ref")
                && red_pass(&red_results, "bad_compatibility_ref")
                && red_pass(&red_results, "bad_native_link_ref")
                && red_pass(&red_results, "bad_benchmark_caveat_ref")
                && red_pass(&red_results, "short_visible_summary"),
        ),
        (
            "bytes_remain_policy_only",
            metrics.policy_metadata_bytes_read == 65_536
                && metrics.current_raw_source_bytes_read == 0
                && metrics.source_archive_bytes_fetched == 0
                && metrics.quarantine_source_bytes_written == 0
                && metrics.product_files_copied == 0
                && metrics.product_dependencies_added == 0
                && metrics.native_link_probe_count == 0
                && metrics.adapter_build_count == 0
                && metrics.index_bytes_opened == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.max_future_raw_source_bytes_read == 196_608
                && red_pass(&red_results, "bad_policy_metadata_bytes")
                && red_pass(&red_results, "future_byte_cap_zero")
                && red_pass(&red_results, "future_byte_cap_over")
                && red_pass(&red_results, "current_raw_source_bytes")
                && red_pass(&red_results, "source_archive_fetched")
                && red_pass(&red_results, "quarantine_source_written")
                && red_pass(&red_results, "product_file_copied")
                && red_pass(&red_results, "product_dependency_added")
                && red_pass(&red_results, "native_link_probe")
                && red_pass(&red_results, "adapter_build")
                && red_pass(&red_results, "index_bytes_opened")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_model_bytes_loaded")
                && red_pass(&red_results, "provider_call"),
        ),
        (
            "no_product_import_native_link_or_benchmark_authority",
            red_pass(&red_results, "row_product_copy_allowed")
                && red_pass(&red_results, "row_product_import_allowed")
                && red_pass(&red_results, "row_product_dependency_allowed")
                && red_pass(&red_results, "row_native_link_allowed")
                && red_pass(&red_results, "row_benchmark_authority")
                && red_pass(&red_results, "row_route_authority"),
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
                && red_pass(&red_results, "status_content_read")
                && red_pass(&red_results, "tier_t2"),
        ),
        (
            "large_local_model_research_bias_preserved",
            set.proof_refs.visible_summary.contains("large local model")
                && set
                    .proof_refs
                    .visible_summary
                    .contains("no hidden route authority")
                && set.proof_refs.visible_summary.contains("no live dense 70B")
                && set.proof_refs.visible_summary.contains("Gemma/QAT")
                && set
                    .proof_refs
                    .visible_summary
                    .contains("70B-class cold assembly"),
        ),
        (
            "reversed_order_address_deterministic",
            set.set_address == reversed.set_address
                && source_inspection_policy_digest(&set)
                    == source_inspection_policy_digest(&reversed),
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
        "policy_row_count",
        metrics.policy_row_count,
        "==",
        22,
        "rows",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "future_read_row_count",
        metrics.future_read_row_count,
        ">=",
        15,
        "rows",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "blocked_row_count",
        metrics.blocked_row_count,
        ">=",
        6,
        "rows",
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
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_future_raw_source_bytes_read",
        metrics.max_future_raw_source_bytes_read,
        "==",
        196_608,
        "bytes",
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
        "source_inspection_policy_address",
        &set.set_address.to_string(),
        "turbovec_real_adapter_source_inspection_policy_probe:",
        "uas_address",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        TURBOVEC_REAL_ADAPTER_SOURCE_INSPECTION_POLICY_NEXT_CURSOR,
        TURBOVEC_REAL_ADAPTER_SOURCE_INSPECTION_POLICY_NEXT_CURSOR,
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
            "kind": "metadata_only_source_inspection_policy_scope",
            "detail": "Policy-only TurboVec source inspection gate. No raw source read, repo clone, source archive fetch, quarantine file write, product import, dependency insertion, adapter build, native-link probe, benchmark authority, index/model/runtime/provider bytes, route/context authority, or live large-local-model claim."
        })],
        notes: "Builds F-TurboVec-RealAdapterSourceInspectionPolicyProbe as a T1/L1 metadata-only policy after the source-byte manifest. It makes the large-local-model compression path more buildable by defining manifest-bound future read rows, blocked rows, clean-room/paraphrase output modes, benchmark caveats, native-link blocks, no-product-graph proof, rollback, RunEventLog, and AnswerPacket visibility before TurboVec motifs can feed Eidos/AppColdStore or Gemma/QAT/70B-class context selection. L2 capability and L3 user-facing model surfaces remain unchanged.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_source_byte_manifest_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec source-byte manifest has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_REAL_ADAPTER_SOURCE_INSPECTION_POLICY_CURSOR)
    {
        return Err("upstream source-byte manifest does not point at inspection policy".into());
    }
    for axis in [
        "/pass_per_axis/upstream_fetch_lease_bound",
        "/pass_per_axis/source_tree_metadata_bound",
        "/pass_per_axis/required_manifest_entries_bound",
        "/pass_per_axis/root_bucket_coverage_bound",
        "/pass_per_axis/path_and_product_root_policy_bound",
        "/pass_per_axis/symlink_binary_benchmark_dispositions_bound",
        "/pass_per_axis/manifest_policy_fail_closed",
        "/pass_per_axis/proof_surfaces_required",
        "/pass_per_axis/bytes_remain_metadata_only",
        "/pass_per_axis/no_route_context_or_hidden_authority",
        "/pass_per_axis/product_and_large_model_claims_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(
                format!("upstream source-byte manifest axis missing or false: {axis}").into(),
            );
        }
    }
    let address = value
        .pointer("/measurements/source_byte_manifest_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("upstream source-byte manifest address missing")?;
    Ok(UasAddress::from_str(address)?)
}

#[allow(clippy::too_many_arguments)]
fn build_set(
    upstream: UasAddress,
    rows: Vec<TurboVecSourceInspectionPolicyRow>,
    policy: TurboVecSourceInspectionPolicy,
    proof_refs: TurboVecSourceInspectionProofRefs,
    byte_ledger: TurboVecSourceInspectionByteLedger,
    product_build: ProductBuild,
    pro_status: ProStatus,
    status: TurboVecSourceInspectionStatus,
    tier: TurboVecSourceInspectionTier,
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<TurboVecRealAdapterSourceInspectionPolicyProbeSet, Box<dyn std::error::Error>> {
    Ok(
        TurboVecRealAdapterSourceInspectionPolicyProbeSet::from_parts(
            upstream,
            rows,
            policy,
            proof_refs,
            byte_ledger,
            product_build,
            pro_status,
            status,
            tier,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            product_capability_promoted,
            route_mutation_allowed,
            model_context_injected,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        )?,
    )
}

fn row(
    path: &str,
    disposition: TurboVecSourceManifestDisposition,
    action: TurboVecInspectionAction,
) -> TurboVecSourceInspectionPolicyRow {
    let blocked = matches!(
        action,
        TurboVecInspectionAction::BlockNativeLink
            | TurboVecInspectionAction::BlockBinaryAsset
            | TurboVecInspectionAction::BlockSymlink
            | TurboVecInspectionAction::BlockIntegration
    );
    TurboVecSourceInspectionPolicyRow {
        path: path.to_string(),
        manifest_disposition: disposition,
        action,
        output_mode: expected_output_mode(action),
        future_source_read_allowed_by_later_witness: !blocked,
        verbatim_code_allowed: false,
        product_copy_allowed: false,
        product_import_allowed: false,
        product_dependency_allowed: false,
        native_link_probe_allowed: false,
        benchmark_authority_allowed: false,
        route_authority_allowed: false,
        clean_room_note_required: !blocked,
        answer_packet_caveat_required: true,
    }
}

fn rows() -> Vec<TurboVecSourceInspectionPolicyRow> {
    use TurboVecInspectionAction::*;
    use TurboVecSourceManifestDisposition::*;
    vec![
        row("LICENSE", ProvenanceOnly, ReadProvenanceMetadata),
        row("README.md", DocumentationOnly, ReadDocumentationSummary),
        row("Cargo.toml", ProvenanceOnly, ReadDependencyMetadata),
        row("Cargo.lock", ProvenanceOnly, ReadDependencyMetadata),
        row(".cargo/config.toml", NativeLinkBlocked, BlockNativeLink),
        row("docs/api.md", DocumentationOnly, ReadApiShape),
        row(
            "examples/downstream-smoke/Cargo.toml",
            IntegrationBlocked,
            BlockIntegration,
        ),
        row(
            "turbovec/Cargo.toml",
            ProvenanceOnly,
            ReadDependencyMetadata,
        ),
        row("turbovec/build.rs", NativeLinkBlocked, BlockNativeLink),
        row("turbovec/src/lib.rs", RustCoreCandidate, ReadApiShape),
        row(
            "turbovec/src/search.rs",
            RustCoreCandidate,
            ReadBehaviorSpec,
        ),
        row(
            "turbovec/src/id_map.rs",
            RustCoreCandidate,
            ReadBehaviorSpec,
        ),
        row("turbovec/src/io.rs", RustCoreCandidate, ReadBehaviorSpec),
        row(
            "turbovec/tests/filtering.rs",
            TestFixtureCandidate,
            ReadTestIntent,
        ),
        row(
            "turbovec/tests/input_validation.rs",
            TestFixtureCandidate,
            ReadTestIntent,
        ),
        row(
            "benchmarks/rabitq_poc/recall_grid.png",
            BinaryAssetBlocked,
            BlockBinaryAsset,
        ),
        row(
            "benchmarks/suite/recall_d1536_4bit.py",
            BenchmarkClaimOnly,
            ReadBenchmarkHarnessMetadata,
        ),
        row(
            "benchmarks/suite/speed_d1536_4bit_arm_mt.py",
            BenchmarkClaimOnly,
            ReadBenchmarkHarnessMetadata,
        ),
        row(
            "turbovec-python/Cargo.toml",
            ProvenanceOnly,
            ReadDependencyMetadata,
        ),
        row("turbovec-python/README.md", SymlinkBlocked, BlockSymlink),
        row(
            "turbovec-python/pyproject.toml",
            ProvenanceOnly,
            ReadDependencyMetadata,
        ),
        row(
            "turbovec-python/python/turbovec/llama_index.py",
            IntegrationBlocked,
            BlockIntegration,
        ),
    ]
}

fn expected_output_mode(action: TurboVecInspectionAction) -> TurboVecInspectionOutputMode {
    use TurboVecInspectionAction::*;
    match action {
        ReadProvenanceMetadata => TurboVecInspectionOutputMode::ProvenanceCard,
        ReadDocumentationSummary => TurboVecInspectionOutputMode::DocumentationSummary,
        ReadApiShape => TurboVecInspectionOutputMode::ApiSignatureOnly,
        ReadBehaviorSpec => TurboVecInspectionOutputMode::BehaviorSpecOnly,
        ReadDependencyMetadata => TurboVecInspectionOutputMode::DependencyRiskNote,
        ReadTestIntent => TurboVecInspectionOutputMode::FixtureIntentOnly,
        ReadBenchmarkHarnessMetadata => TurboVecInspectionOutputMode::BenchmarkCaveatOnly,
        BlockNativeLink | BlockBinaryAsset | BlockSymlink | BlockIntegration => {
            TurboVecInspectionOutputMode::Blocked
        }
    }
}

fn policy() -> TurboVecSourceInspectionPolicy {
    TurboVecSourceInspectionPolicy::fail_closed()
}

fn byte_ledger() -> TurboVecSourceInspectionByteLedger {
    TurboVecSourceInspectionByteLedger::metadata_only()
}

fn proof_refs() -> TurboVecSourceInspectionProofRefs {
    TurboVecSourceInspectionProofRefs {
        source_byte_manifest_ref: "artifact:turbovec_real_adapter_source_byte_manifest_probe:result"
            .to_string(),
        provenance_ref: "provenance:turbovec-source-inspection:pinned-mit-460-forks".to_string(),
        clean_room_ref: "clean_room:turbovec-source-inspection:paraphrase-only".to_string(),
        source_card_ref: "source_card:turbovec-source-inspection:future-motif-cards".to_string(),
        fork_sweep_ref: "fork_sweep:turbovec-source-inspection:github-forks-metadata".to_string(),
        no_product_graph_ref: "no_product_graph:turbovec-source-inspection:deny".to_string(),
        rollback_ref: "rollback:turbovec-source-inspection:policy-tombstone".to_string(),
        run_event_log_ref: "run_event_log:turbovec-source-inspection:policy".to_string(),
        answer_packet_ref: "answer_packet:turbovec-source-inspection:policy".to_string(),
        compatibility_fence_ref: "compat:turbovec-source-inspection:apple-silicon".to_string(),
        native_link_block_ref: "native_link:turbovec-source-inspection:block-blas-build-rs"
            .to_string(),
        benchmark_caveat_ref: "benchmark_caveat:turbovec-source-inspection:non-authority"
            .to_string(),
        visible_summary: "large local model source inspection policy for TurboVec: clean-room paraphrase-only API/test/behavior motifs, no hidden route authority, no live dense 70B, no product import, no dependency insertion, no native-link build, no benchmark authority, no route mutation, no model-context injection, no raw source bytes in this witness, and AnswerPacket-visible rollback before any compressed retrieval route can cite source material for Gemma/QAT or 70B-class cold assembly.".to_string(),
    }
}

fn red_fixture_results(upstream: &UasAddress) -> Vec<(String, bool)> {
    let mut results = Vec::with_capacity(96);
    push_case(&mut results, "bad_upstream_cursor", || {
        let bad = UasAddress::new(
            UasKind::Other("not_source_manifest".to_string()),
            b"wrong-upstream",
            1,
        );
        default_with_upstream(bad).is_err()
    });
    for (name, missing) in [
        ("missing_docs_api", "docs/api.md"),
        ("missing_search_rs", "turbovec/src/search.rs"),
    ] {
        push_case(&mut results, name, || {
            let mut bad_rows = rows();
            bad_rows.retain(|row| row.path != missing);
            default_with_rows(upstream.clone(), bad_rows).is_err()
        });
    }
    push_case(&mut results, "duplicate_row_path", || {
        let mut bad_rows = rows();
        bad_rows.push(bad_rows[0].clone());
        default_with_rows(upstream.clone(), bad_rows).is_err()
    });
    for (name, path) in [
        ("absolute_path", "/tmp/turbovec/src/lib.rs"),
        ("traversal_path", "turbovec/../src/lib.rs"),
        ("product_path_agent_core", "agent_core/src/lib.rs"),
    ] {
        push_case(&mut results, name, || {
            let mut bad_rows = rows();
            bad_rows[0].path = path.to_string();
            default_with_rows(upstream.clone(), bad_rows).is_err()
        });
    }
    for (name, mutator) in row_flag_mutators() {
        push_case(&mut results, name, || {
            let mut bad_rows = rows();
            mutator(&mut bad_rows);
            default_with_rows(upstream.clone(), bad_rows).is_err()
        });
    }
    for (name, mutator) in policy_mutators() {
        push_case(&mut results, name, || {
            let mut bad_policy = policy();
            mutator(&mut bad_policy);
            default_with_policy(upstream.clone(), bad_policy).is_err()
        });
    }
    for (name, mutator) in proof_ref_mutators() {
        push_case(&mut results, name, || {
            let mut bad_refs = proof_refs();
            mutator(&mut bad_refs);
            default_with_proof_refs(upstream.clone(), bad_refs).is_err()
        });
    }
    for (name, mutator) in ledger_mutators() {
        push_case(&mut results, name, || {
            let mut bad_ledger = byte_ledger();
            mutator(&mut bad_ledger);
            default_with_ledger(upstream.clone(), bad_ledger).is_err()
        });
    }
    for (name, flag) in [
        ("route_mutation", ClaimFlag::RouteMutation),
        ("context_injection", ClaimFlag::ContextInjection),
        ("hidden_authority", ClaimFlag::HiddenAuthority),
        ("hidden_cloud", ClaimFlag::HiddenCloud),
        ("product_promoted", ClaimFlag::ProductPromotion),
        ("live_large_model", ClaimFlag::LiveLargeModel),
        ("ssd_as_ram", ClaimFlag::SsdAsRam),
    ] {
        push_case(&mut results, name, || {
            default_with_claim_flag(upstream.clone(), flag).is_err()
        });
    }
    for (name, build, pro_status, status, tier) in [
        (
            "product_build_mas",
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            TurboVecSourceInspectionStatus::PolicyOnly,
            TurboVecSourceInspectionTier::T1L1Metadata,
        ),
        (
            "pro_status_live",
            ProductBuild::Pro,
            ProStatus::Live,
            TurboVecSourceInspectionStatus::PolicyOnly,
            TurboVecSourceInspectionTier::T1L1Metadata,
        ),
        (
            "status_content_read",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceInspectionStatus::SourceContentReadByLaterWitness,
            TurboVecSourceInspectionTier::T1L1Metadata,
        ),
        (
            "tier_t2",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceInspectionStatus::PolicyOnly,
            TurboVecSourceInspectionTier::T2L2Route,
        ),
    ] {
        push_case(&mut results, name, || {
            build_set(
                upstream.clone(),
                rows(),
                policy(),
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
            .is_err()
        });
    }
    push_case(&mut results, "missing_required_organ", || {
        TurboVecRealAdapterSourceInspectionPolicyProbeSet::from_parts(
            upstream.clone(),
            rows(),
            policy(),
            proof_refs(),
            byte_ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceInspectionStatus::PolicyOnly,
            TurboVecSourceInspectionTier::T1L1Metadata,
            vec![TurboVecIndexOrgan::Eidos],
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

type RowMutator = fn(&mut Vec<TurboVecSourceInspectionPolicyRow>);
type PolicyMutator = fn(&mut TurboVecSourceInspectionPolicy);
type ProofRefMutator = fn(&mut TurboVecSourceInspectionProofRefs);
type LedgerMutator = fn(&mut TurboVecSourceInspectionByteLedger);

fn row_flag_mutators() -> Vec<(&'static str, RowMutator)> {
    vec![
        ("blocked_row_read_allowed", |rows| {
            let row = find_row(rows, "turbovec/build.rs");
            row.future_source_read_allowed_by_later_witness = true;
        }),
        ("blocked_row_clean_room_note", |rows| {
            let row = find_row(rows, "turbovec/build.rs");
            row.clean_room_note_required = true;
        }),
        ("inspectable_row_no_future_read", |rows| {
            let row = find_row(rows, "turbovec/src/search.rs");
            row.future_source_read_allowed_by_later_witness = false;
        }),
        ("wrong_output_mode", |rows| {
            let row = find_row(rows, "docs/api.md");
            row.output_mode = TurboVecInspectionOutputMode::BehaviorSpecOnly;
        }),
        ("action_disposition_mismatch", |rows| {
            let row = find_row(rows, "turbovec/src/search.rs");
            row.action = TurboVecInspectionAction::ReadTestIntent;
        }),
        ("missing_answer_packet_caveat", |rows| {
            rows[0].answer_packet_caveat_required = false;
        }),
        ("verbatim_code_allowed", |rows| {
            rows[0].verbatim_code_allowed = true;
        }),
        ("row_product_copy_allowed", |rows| {
            rows[0].product_copy_allowed = true;
        }),
        ("row_product_import_allowed", |rows| {
            rows[0].product_import_allowed = true;
        }),
        ("row_product_dependency_allowed", |rows| {
            rows[0].product_dependency_allowed = true;
        }),
        ("row_native_link_allowed", |rows| {
            rows[0].native_link_probe_allowed = true;
        }),
        ("row_benchmark_authority", |rows| {
            let row = find_row(rows, "benchmarks/suite/recall_d1536_4bit.py");
            row.benchmark_authority_allowed = true;
        }),
        ("row_route_authority", |rows| {
            rows[0].route_authority_allowed = true;
        }),
    ]
}

fn policy_mutators() -> Vec<(&'static str, PolicyMutator)> {
    vec![
        ("policy_not_manifest_bound", |policy| {
            policy.manifest_bound = false
        }),
        ("policy_source_bytes_now", |policy| {
            policy.source_bytes_read_now = true
        }),
        ("policy_raw_content_now", |policy| {
            policy.raw_content_read_now = true
        }),
        ("policy_owner_not_required", |policy| {
            policy.future_source_read_requires_owner_approval = false;
        }),
        ("policy_quarantine_not_required", |policy| {
            policy.future_source_read_requires_quarantine = false;
        }),
        ("policy_manifest_row_not_required", |policy| {
            policy.future_source_read_requires_manifest_row = false;
        }),
        ("policy_verbatim_not_forbidden", |policy| {
            policy.verbatim_code_forbidden = false;
        }),
        ("policy_product_import", |policy| {
            policy.product_import_allowed = true
        }),
        ("policy_dependency", |policy| {
            policy.product_dependency_allowed = true;
        }),
        ("policy_native_link", |policy| {
            policy.native_link_probe_allowed = true
        }),
        ("policy_benchmark_authority", |policy| {
            policy.benchmark_authority_allowed = true;
        }),
        ("policy_runtime", |policy| {
            policy.runtime_execution_allowed = true
        }),
        ("policy_route_authority", |policy| {
            policy.route_authority_allowed = true;
        }),
    ]
}

fn proof_ref_mutators() -> Vec<(&'static str, ProofRefMutator)> {
    vec![
        ("bad_manifest_ref", |refs| {
            refs.source_byte_manifest_ref = "artifact:wrong:result".to_string();
        }),
        ("bad_provenance_ref", |refs| {
            refs.provenance_ref = "bad:turbovec".to_string();
        }),
        ("bad_clean_room_ref", |refs| {
            refs.clean_room_ref = "bad:turbovec".to_string();
        }),
        ("bad_source_card_ref", |refs| {
            refs.source_card_ref = "bad:turbovec".to_string();
        }),
        ("bad_fork_sweep_ref", |refs| {
            refs.fork_sweep_ref = "bad:turbovec".to_string();
        }),
        ("bad_no_product_graph_ref", |refs| {
            refs.no_product_graph_ref = "bad:turbovec".to_string();
        }),
        ("bad_rollback_ref", |refs| {
            refs.rollback_ref = "bad:turbovec".to_string();
        }),
        ("bad_run_event_log_ref", |refs| {
            refs.run_event_log_ref = "bad:turbovec".to_string();
        }),
        ("bad_answer_packet_ref", |refs| {
            refs.answer_packet_ref = "bad:turbovec".to_string();
        }),
        ("bad_compatibility_ref", |refs| {
            refs.compatibility_fence_ref = "bad:turbovec".to_string();
        }),
        ("bad_native_link_ref", |refs| {
            refs.native_link_block_ref = "bad:turbovec".to_string();
        }),
        ("bad_benchmark_caveat_ref", |refs| {
            refs.benchmark_caveat_ref = "bad:turbovec".to_string();
        }),
        ("short_visible_summary", |refs| {
            refs.visible_summary = "too short".to_string();
        }),
    ]
}

fn ledger_mutators() -> Vec<(&'static str, LedgerMutator)> {
    vec![
        ("bad_policy_metadata_bytes", |ledger| {
            ledger.policy_metadata_bytes_read = 0;
        }),
        ("future_byte_cap_zero", |ledger| {
            ledger.max_future_raw_source_bytes_read = 0;
        }),
        ("future_byte_cap_over", |ledger| {
            ledger.max_future_raw_source_bytes_read = 196_609;
        }),
        ("current_raw_source_bytes", |ledger| {
            ledger.current_raw_source_bytes_read = 1;
        }),
        ("source_archive_fetched", |ledger| {
            ledger.source_archive_bytes_fetched = 1;
        }),
        ("quarantine_source_written", |ledger| {
            ledger.quarantine_source_bytes_written = 1;
        }),
        ("product_file_copied", |ledger| {
            ledger.product_files_copied = 1
        }),
        ("product_dependency_added", |ledger| {
            ledger.product_dependencies_added = 1;
        }),
        ("native_link_probe", |ledger| {
            ledger.native_link_probe_count = 1
        }),
        ("adapter_build", |ledger| ledger.adapter_build_count = 1),
        ("index_bytes_opened", |ledger| ledger.index_bytes_opened = 1),
        ("model_bytes_loaded", |ledger| ledger.model_bytes_loaded = 1),
        ("runtime_model_bytes_loaded", |ledger| {
            ledger.runtime_model_bytes_loaded = 1;
        }),
        ("provider_call", |ledger| ledger.provider_calls_made = 1),
    ]
}

fn find_row<'a>(
    rows: &'a mut [TurboVecSourceInspectionPolicyRow],
    path: &str,
) -> &'a mut TurboVecSourceInspectionPolicyRow {
    rows.iter_mut()
        .find(|row| row.path == path)
        .expect("fixture row")
}

fn default_with_upstream(
    upstream: UasAddress,
) -> Result<TurboVecRealAdapterSourceInspectionPolicyProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        rows(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceInspectionStatus::PolicyOnly,
        TurboVecSourceInspectionTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn default_with_rows(
    upstream: UasAddress,
    rows: Vec<TurboVecSourceInspectionPolicyRow>,
) -> Result<TurboVecRealAdapterSourceInspectionPolicyProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        rows,
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceInspectionStatus::PolicyOnly,
        TurboVecSourceInspectionTier::T1L1Metadata,
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
    policy: TurboVecSourceInspectionPolicy,
) -> Result<TurboVecRealAdapterSourceInspectionPolicyProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        rows(),
        policy,
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceInspectionStatus::PolicyOnly,
        TurboVecSourceInspectionTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn default_with_proof_refs(
    upstream: UasAddress,
    proof_refs: TurboVecSourceInspectionProofRefs,
) -> Result<TurboVecRealAdapterSourceInspectionPolicyProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        rows(),
        policy(),
        proof_refs,
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceInspectionStatus::PolicyOnly,
        TurboVecSourceInspectionTier::T1L1Metadata,
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
    ledger: TurboVecSourceInspectionByteLedger,
) -> Result<TurboVecRealAdapterSourceInspectionPolicyProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        rows(),
        policy(),
        proof_refs(),
        ledger,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceInspectionStatus::PolicyOnly,
        TurboVecSourceInspectionTier::T1L1Metadata,
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
) -> Result<TurboVecRealAdapterSourceInspectionPolicyProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        rows(),
        policy(),
        proof_refs(),
        byte_ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecSourceInspectionStatus::PolicyOnly,
        TurboVecSourceInspectionTier::T1L1Metadata,
        matches!(flag, ClaimFlag::ProductPromotion),
        matches!(flag, ClaimFlag::RouteMutation),
        matches!(flag, ClaimFlag::ContextInjection),
        matches!(flag, ClaimFlag::HiddenAuthority),
        matches!(flag, ClaimFlag::HiddenCloud),
        matches!(flag, ClaimFlag::LiveLargeModel),
        matches!(flag, ClaimFlag::SsdAsRam),
    )
}

fn push_case<F>(results: &mut Vec<(String, bool)>, name: &str, predicate: F)
where
    F: FnOnce() -> bool,
{
    results.push((name.to_string(), predicate()));
}

fn red_pass(results: &[(String, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(case, _)| case == name)
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
enum ClaimFlag {
    ProductPromotion,
    RouteMutation,
    ContextInjection,
    HiddenAuthority,
    HiddenCloud,
    LiveLargeModel,
    SsdAsRam,
}
