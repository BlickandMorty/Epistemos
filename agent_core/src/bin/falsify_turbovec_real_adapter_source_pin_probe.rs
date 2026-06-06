//! `falsify_turbovec_real_adapter_source_pin_probe`
//!
//! Metadata-only witness for `F-TurboVec-RealAdapterSourcePinProbe`.
//! It pins the first real upstream TurboVec source revision and public-fork
//! sweep without fetching, cloning, importing, building, routing, or loading
//! any source/index/model bytes.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, TurboVecForkDisposition, TurboVecForkSweepRecord, TurboVecIndexOrgan,
    TurboVecPinnedSourceCard, TurboVecRealAdapterSourcePinMetrics,
    TurboVecRealAdapterSourcePinProbeSet, TurboVecRealAdapterSourcePinStatus,
    TurboVecRealAdapterSourcePinTier, TurboVecSourcePinAllowedAction, TurboVecSourcePinByteLedger,
    TurboVecSourcePinPolicy, UasAddress, TURBOVEC_REAL_ADAPTER_SOURCE_PIN_CURSOR,
    TURBOVEC_REAL_ADAPTER_SOURCE_PIN_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RealAdapterSourcePinProbe";
const FIXTURE_ID: &str = "turbovec_real_adapter_source_pin_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_real_adapter_source_pin_probe.sh";
const RESULT: &str = "artifacts/falsifiers/turbovec_real_adapter_source_pin_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_owner_approval_probe/result.json";
const SOURCE_CARD_ID: &str = "ryancodrai_turbovec_upstream_source_pin";
const SOURCE_URL: &str = "https://github.com/RyanCodrai/turbovec";
const OWNER_REPO: &str = "RyanCodrai/turbovec";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const README_SHA: &str = "1bcd3121da5c5da47e2259adf1959f9df6af06ef";
const LICENSE_SHA: &str = "e62ad7c6028ad9b2f9b4c1776dc7d4a9c942fced";
const CARGO_TOML_SHA: &str = "9bf15f9f5eba2de42db231e9235c4181f620277f";
const SET_METADATA_BYTES: u64 = 96_000;
const PLANNED_QUARANTINE_BYTES: u64 = 8 * 1024 * 1024;
const RED_FIXTURE_FLOOR: u64 = 52;

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
        "{FALSIFIER_ID}: overall_pass={} pinned_revision={} fork_records={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["pinned_revision"].value,
        artifact.measurements["fork_record_count"].value,
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
    let upstream = upstream_owner_gate_address()?;
    let card = accepted_source_card();
    let forks = accepted_fork_records();
    let set = build_set(upstream.clone(), card.clone(), forks.clone())?;
    let reversed = build_set(
        upstream,
        card.clone(),
        forks.iter().cloned().rev().collect(),
    )?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&card, &forks)?;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_owner_gate_bound",
            set.upstream_owner_gate_witness_ref
                == "artifact:turbovec_real_adapter_owner_approval_probe:result"
                && set
                    .upstream_owner_gate_address
                    .to_string()
                    .starts_with("turbovec_real_adapter_owner_approval_probe:"),
        ),
        (
            "pinned_revision_bound",
            set.source_card.pinned_revision == PINNED_REVISION
                && red_pass(&red_results, "bad_revision_short")
                && red_pass(&red_results, "bad_revision_nonhex"),
        ),
        (
            "branch_protected",
            set.source_card.branch_protected && red_pass(&red_results, "branch_not_protected"),
        ),
        (
            "primary_source_bound",
            set.source_card.source_url == SOURCE_URL
                && set.source_card.owner_repo == OWNER_REPO
                && set.source_card.default_branch == "main"
                && set.source_card.license_id == "MIT"
                && red_pass(&red_results, "bad_source_url")
                && red_pass(&red_results, "bad_owner_repo")
                && red_pass(&red_results, "bad_default_branch")
                && red_pass(&red_results, "bad_license"),
        ),
        (
            "github_api_refs_bound",
            metrics.github_api_ref_count >= 7
                && red_pass(&red_results, "missing_api_repo")
                && red_pass(&red_results, "missing_api_branch")
                && red_pass(&red_results, "missing_api_commits")
                && red_pass(&red_results, "missing_api_forks")
                && red_pass(&red_results, "missing_api_issues")
                && red_pass(&red_results, "missing_api_contents")
                && red_pass(&red_results, "bad_api_prefix"),
        ),
        (
            "content_sha_refs_bound",
            metrics.content_sha_ref_count == 3
                && red_pass(&red_results, "missing_readme_sha")
                && red_pass(&red_results, "missing_license_sha")
                && red_pass(&red_results, "missing_cargo_toml_sha")
                && red_pass(&red_results, "missing_content_ref"),
        ),
        (
            "issue_refs_bound",
            metrics.issue_ref_count == 2
                && red_pass(&red_results, "missing_swift_issue")
                && red_pass(&red_results, "missing_benchmark_issue"),
        ),
        (
            "release_absence_caveat_bound",
            metrics.release_count == 0
                && red_pass(&red_results, "github_release_without_caveat")
                && red_pass(&red_results, "bad_release_caveat"),
        ),
        (
            "fork_sweep_complete",
            metrics.fork_record_count == 10
                && metrics.unarchived_enabled_fork_count == 10
                && red_pass(&red_results, "too_few_forks")
                && red_pass(&red_results, "duplicate_fork")
                && red_pass(&red_results, "archived_fork")
                && red_pass(&red_results, "disabled_fork")
                && red_pass(&red_results, "fork_bad_url")
                && red_pass(&red_results, "fork_bad_branch")
                && red_pass(&red_results, "fork_bad_license")
                && red_pass(&red_results, "fork_bad_sha"),
        ),
        (
            "fork_disposition_diversity",
            metrics.matching_upstream_fork_count == 3
                && metrics.lagging_fork_count == 3
                && metrics.diverged_fork_count == 4
                && red_pass(&red_results, "matching_fork_bad_sha")
                && red_pass(&red_results, "lagging_fork_bad_sha")
                && red_pass(&red_results, "diverged_fork_bad_sha")
                && red_pass(&red_results, "no_matching_fork")
                && red_pass(&red_results, "no_lagging_fork")
                && red_pass(&red_results, "no_diverged_fork"),
        ),
        (
            "metadata_only_source_pin",
            matches!(
                set.source_card.allowed_action,
                TurboVecSourcePinAllowedAction::PinnedMetadataOnly
            ) && set.source_card.source_pin_is_metadata_only
                && red_pass(&red_results, "fetch_quarantine_bytes_action")
                && red_pass(&red_results, "adapter_wrap")
                && red_pass(&red_results, "direct_import")
                && red_pass(&red_results, "product_integration")
                && red_pass(&red_results, "source_pin_not_metadata_only"),
        ),
        (
            "provenance_dependency_and_proof_surfaces_required",
            red_pass(&red_results, "bad_owner_selection_ref")
                && red_pass(&red_results, "bad_source_pin_ref")
                && red_pass(&red_results, "bad_fork_sweep_ref")
                && red_pass(&red_results, "missing_provenance")
                && red_pass(&red_results, "missing_dependency_manifest")
                && red_pass(&red_results, "missing_rollback")
                && red_pass(&red_results, "missing_run_event_log")
                && red_pass(&red_results, "missing_answer_packet")
                && red_pass(&red_results, "missing_compatibility_fence")
                && red_pass(&red_results, "short_summary"),
        ),
        (
            "external_and_product_bytes_zero",
            metrics.fetched_repo_bytes == 0
                && metrics.cloned_repo_bytes == 0
                && metrics.copied_product_file_count == 0
                && metrics.imported_external_crate_count == 0
                && metrics.built_external_binary_count == 0
                && metrics.opened_product_index_bytes == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "repo_fetched")
                && red_pass(&red_results, "repo_cloned_bytes")
                && red_pass(&red_results, "copied_product_file")
                && red_pass(&red_results, "external_crate_import")
                && red_pass(&red_results, "built_binary")
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
                && red_pass(&red_results, "owner_runtime_approval_granted")
                && red_pass(&red_results, "dependency_added")
                && red_pass(&red_results, "source_copied")
                && red_pass(&red_results, "adapter_built")
                && red_pass(&red_results, "benchmark_laundered")
                && red_pass(&red_results, "route_mutation")
                && red_pass(&red_results, "context_injection")
                && red_pass(&red_results, "hidden_authority")
                && red_pass(&red_results, "hidden_cloud"),
        ),
        (
            "product_and_large_model_claims_rejected",
            red_pass(&red_results, "product_promoted")
                && red_pass(&red_results, "set_product_promoted")
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
            "fork_record_count",
            metrics.fork_record_count,
            10,
            "==",
            "forks",
        ),
        (
            "matching_upstream_fork_count",
            metrics.matching_upstream_fork_count,
            3,
            "==",
            "forks",
        ),
        (
            "lagging_fork_count",
            metrics.lagging_fork_count,
            3,
            "==",
            "forks",
        ),
        (
            "diverged_fork_count",
            metrics.diverged_fork_count,
            4,
            "==",
            "forks",
        ),
        (
            "unique_fork_sha_count",
            metrics.unique_fork_sha_count,
            7,
            ">=",
            "sha",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            RED_FIXTURE_FLOOR,
            ">=",
            "fixtures",
        ),
        (
            "metadata_bytes_read",
            SET_METADATA_BYTES,
            768 * 1024,
            "<=",
            "bytes",
        ),
        (
            "planned_quarantine_bytes",
            metrics.max_planned_quarantine_bytes,
            PLANNED_QUARANTINE_BYTES,
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
        "source_pin_address",
        &set.set_address.to_string(),
        "turbovec_real_adapter_source_pin_probe:",
        "uas_address",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        TURBOVEC_REAL_ADAPTER_SOURCE_PIN_NEXT_CURSOR,
        TURBOVEC_REAL_ADAPTER_SOURCE_PIN_NEXT_CURSOR,
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
            "kind": "metadata_only_source_pin_scope",
            "detail": "Pinned GitHub metadata and fork records only. No repository bytes fetched or cloned, no dependency added, no product source copied, no adapter built or run, no index/model/runtime/provider bytes loaded, and no route/context authority granted."
        })],
        notes: "Builds F-TurboVec-RealAdapterSourcePinProbe as a T1/L1 metadata-only source pin for large-local-model compressed retrieval research. It binds RyanCodrai/turbovec main to pinned revision efe29a184986cbf562a9847c2ac52a2990bfaca2, MIT/content SHA refs, open Swift/macOS and benchmark issues, release-absence caveat, top public fork sweep, clean-room provenance, rollback, RunEventLog, AnswerPacket, compatibility fence, zero external/product/model/provider bytes, and no live large-model or product capability promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_owner_gate_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec real-adapter owner gate has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_REAL_ADAPTER_SOURCE_PIN_CURSOR)
    {
        return Err("upstream owner gate does not point at source-pin probe".into());
    }
    for axis in [
        "/pass_per_axis/owner_approval_pending_fail_closed",
        "/pass_per_axis/source_pin_pending_until_owner_selection",
        "/pass_per_axis/external_and_product_bytes_zero",
        "/pass_per_axis/no_route_context_or_hidden_authority",
        "/pass_per_axis/product_and_large_model_claims_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(format!("upstream owner gate axis missing or false: {axis}").into());
        }
    }
    if value
        .pointer("/measurements/source_card_count/value")
        .and_then(serde_json::Value::as_u64)
        != Some(1)
    {
        return Err("upstream owner gate source card count mismatch".into());
    }
    let address = value
        .pointer("/measurements/real_adapter_owner_approval_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("upstream real-adapter owner approval address missing")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream: UasAddress,
    card: TurboVecPinnedSourceCard,
    forks: Vec<TurboVecForkSweepRecord>,
) -> Result<TurboVecRealAdapterSourcePinProbeSet, Box<dyn std::error::Error>> {
    Ok(TurboVecRealAdapterSourcePinProbeSet::from_parts(
        upstream,
        card,
        forks,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecRealAdapterSourcePinStatus::PinnedMetadataOnly,
        TurboVecRealAdapterSourcePinTier::T1L1Metadata,
        organs(),
        TurboVecSourcePinPolicy::fail_closed(),
        SET_METADATA_BYTES,
        false,
    )?)
}

fn accepted_source_card() -> TurboVecPinnedSourceCard {
    TurboVecPinnedSourceCard {
        source_card_id: SOURCE_CARD_ID.to_string(),
        source_url: SOURCE_URL.to_string(),
        owner_repo: OWNER_REPO.to_string(),
        default_branch: "main".to_string(),
        pinned_revision: PINNED_REVISION.to_string(),
        branch_protected: true,
        license_id: "MIT".to_string(),
        stargazers_count: 4_711,
        fork_count: 453,
        open_issue_count: 5,
        release_count: 0,
        repo_size_kib: 4_970,
        pushed_at_utc: "2026-05-30T13:12:07Z".to_string(),
        updated_at_utc: "2026-06-06T13:10:07Z".to_string(),
        readme_sha: README_SHA.to_string(),
        license_sha: LICENSE_SHA.to_string(),
        cargo_toml_sha: CARGO_TOML_SHA.to_string(),
        api_refs: vec![
            "github_api:turbovec:repo:RyanCodrai/turbovec:stars4711_forks453_open5"
                .to_string(),
            "github_api:turbovec:branch:main:protected:true".to_string(),
            "github_api:turbovec:commits:latest5:head_efe29a".to_string(),
            "github_api:turbovec:forks:top10:sampled_2026_06_06".to_string(),
            "github_api:turbovec:issues:open:86_85_70_68_65".to_string(),
            "github_api:turbovec:contents:readme-license-cargo".to_string(),
            "github_content:turbovec:readme:1bcd3121da5c5da47e2259adf1959f9df6af06ef"
                .to_string(),
            "github_content:turbovec:license:e62ad7c6028ad9b2f9b4c1776dc7d4a9c942fced"
                .to_string(),
            "github_content:turbovec:cargo_toml:9bf15f9f5eba2de42db231e9235c4181f620277f"
                .to_string(),
        ],
        issue_refs: vec![
            "github_issue:turbovec:86:proposal-swift-macos-binding".to_string(),
            "github_issue:turbovec:65:add-insertion-removal-speed-benchmarks".to_string(),
        ],
        release_caveat_ref:
            "release_caveat:turbovec:no_github_releases_commit_message_not_product_proof"
                .to_string(),
        owner_selection_ref:
            "owner_selection:metadata_pin_only:upstream_main_selected_by_primary_api".to_string(),
        source_pin_ref:
            "source_pin:pinned_metadata_only:efe29a184986cbf562a9847c2ac52a2990bfaca2"
                .to_string(),
        fork_sweep_ref: "fork_sweep:turbovec:top10_public_forks_api_metadata_only".to_string(),
        provenance_ref: "provenance:turbovec-source-pin:clean-room-source-card".to_string(),
        dependency_manifest_ref:
            "dependency_manifest:turbovec-source-pin:no-product-dependency-until-envelope"
                .to_string(),
        rollback_ref: "rollback:turbovec-source-pin:drop-card-before-quarantine".to_string(),
        run_event_log_ref: "run_event_log:turbovec-source-pin:metadata-only".to_string(),
        answer_packet_ref: "answer_packet:turbovec-source-pin:visible-non-promotion".to_string(),
        compatibility_fence_ref: "compat:turbovec-source-pin:no-runtime-bytes".to_string(),
        visible_summary: "TurboVec upstream main is pinned as metadata-only source evidence after a primary GitHub API and public-fork sweep. This enables later dependency-envelope and quarantine planning for compressed retrieval around large local models, but it approves no repository fetch, source import, adapter wrapping, product route mutation, model context injection, live 70B claim, or user-facing capability.".to_string(),
        allowed_action: TurboVecSourcePinAllowedAction::PinnedMetadataOnly,
        byte_ledger: TurboVecSourcePinByteLedger::metadata_only(
            SET_METADATA_BYTES,
            PLANNED_QUARANTINE_BYTES,
        ),
        source_pin_is_metadata_only: true,
        owner_runtime_approval_granted: false,
        repo_fetched_or_cloned: false,
        dependency_added_to_product: false,
        source_copied_to_product: false,
        adapter_built_or_run: false,
        upstream_benchmark_claimed_as_product_proof: false,
        route_mutation_allowed: false,
        model_context_injected: false,
        hidden_route_authority: false,
        hidden_cloud_fallback_allowed: false,
        product_capability_promoted: false,
        live_large_model_claimed: false,
        ssd_as_ram_claimed: false,
    }
}

fn accepted_fork_records() -> Vec<TurboVecForkSweepRecord> {
    vec![
        fork(
            "manuelapetsi/turbovec",
            "efe29a184986cbf562a9847c2ac52a2990bfaca2",
            4_970,
            0,
            "2026-05-30T13:12:07Z",
            TurboVecForkDisposition::MatchesPinnedUpstream,
        ),
        fork(
            "MSAIGlobal/turbovec",
            "efe29a184986cbf562a9847c2ac52a2990bfaca2",
            4_970,
            0,
            "2026-05-30T13:12:07Z",
            TurboVecForkDisposition::MatchesPinnedUpstream,
        ),
        fork(
            "pellera9/turbovec",
            "efe29a184986cbf562a9847c2ac52a2990bfaca2",
            4_970,
            0,
            "2026-05-30T13:12:07Z",
            TurboVecForkDisposition::MatchesPinnedUpstream,
        ),
        fork(
            "wachirawit29/turbovec",
            "06155d9bf2219f0d23287d1d12b5598e676a27b1",
            4_904,
            0,
            "2026-05-27T17:40:37Z",
            TurboVecForkDisposition::LaggingKnownUpstreamCommit,
        ),
        fork(
            "Igorrmcastro1709/turbovec",
            "1aca71ca7e65951b6ed11cde29e904afe124291a",
            4_919,
            0,
            "2026-05-29T18:18:55Z",
            TurboVecForkDisposition::LaggingKnownUpstreamCommit,
        ),
        fork(
            "rohitg00/turbovec",
            "1aca71ca7e65951b6ed11cde29e904afe124291a",
            4_919,
            0,
            "2026-05-29T18:18:55Z",
            TurboVecForkDisposition::LaggingKnownUpstreamCommit,
        ),
        fork(
            "federicogrecobarragan-prog/turbovec",
            "3bde2c31c24ce23e3d85598f5fd7cae4f85e41a4",
            4_971,
            0,
            "2026-05-27T13:53:51Z",
            TurboVecForkDisposition::DivergedFromSampledHistory,
        ),
        fork(
            "NullLabTests/turbovec",
            "0c9758b9f4608db9818e4175ec2c29f742958869",
            4_827,
            0,
            "2026-05-21T17:12:32Z",
            TurboVecForkDisposition::DivergedFromSampledHistory,
        ),
        fork(
            "bab321-AI/turbovec",
            "3d0d6afb4edf79a1989ad7e225561d1c8e06e3f5",
            4_814,
            0,
            "2026-05-22T02:30:46Z",
            TurboVecForkDisposition::DivergedFromSampledHistory,
        ),
        fork(
            "AKHtun/turbovec-wecos",
            "4a4f2cd2db233f24405911b1ceaf1823fa23b4ac",
            4_814,
            2,
            "2026-06-06T01:12:14Z",
            TurboVecForkDisposition::DivergedFromSampledHistory,
        ),
    ]
}

fn fork(
    repo: &str,
    sha: &str,
    size_kib: u64,
    open_issue_count: u64,
    pushed_at: &str,
    disposition: TurboVecForkDisposition,
) -> TurboVecForkSweepRecord {
    TurboVecForkSweepRecord {
        fork_repo: repo.to_string(),
        fork_url: format!("https://github.com/{repo}"),
        default_branch: "main".to_string(),
        branch_sha: sha.to_string(),
        license_id: "MIT".to_string(),
        stargazers_count: 1,
        open_issue_count,
        repo_size_kib: size_kib,
        pushed_at_utc: pushed_at.to_string(),
        archived: false,
        disabled: false,
        branch_protected: false,
        disposition,
    }
}

fn red_fixture_results(
    card: &TurboVecPinnedSourceCard,
    forks: &[TurboVecForkSweepRecord],
) -> Result<Vec<(String, bool)>, Box<dyn std::error::Error>> {
    let upstream = UasAddress::from_str(
        "turbovec_real_adapter_owner_approval_probe:694aedb3ab2f1c70671cc1863e1d829af1b2cd311604cbc718a903e4b873c0b5@1779040800000",
    )?;
    let mut results = Vec::new();

    let mut push_card = |name: &str, mutate: fn(&mut TurboVecPinnedSourceCard)| {
        let mut red_card = card.clone();
        mutate(&mut red_card);
        let passed = build_set(upstream.clone(), red_card, forks.to_vec()).is_err();
        results.push((name.to_string(), passed));
    };

    push_card("bad_source_url", |card| {
        card.source_url = "http://example.com".to_string()
    });
    push_card("bad_owner_repo", |card| {
        card.owner_repo = "other/repo".to_string()
    });
    push_card("bad_default_branch", |card| {
        card.default_branch = "master".to_string()
    });
    push_card("bad_revision_short", |card| {
        card.pinned_revision = "short".to_string()
    });
    push_card("bad_revision_nonhex", |card| {
        card.pinned_revision = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz".to_string()
    });
    push_card("branch_not_protected", |card| card.branch_protected = false);
    push_card("bad_license", |card| {
        card.license_id = "NOASSERTION".to_string()
    });
    push_card("zero_stars", |card| card.stargazers_count = 0);
    push_card("insufficient_fork_count", |card| card.fork_count = 1);
    push_card("missing_open_issues", |card| card.open_issue_count = 0);
    push_card("github_release_without_caveat", |card| {
        card.release_count = 1
    });
    push_card("missing_readme_sha", |card| card.readme_sha.clear());
    push_card("missing_license_sha", |card| card.license_sha.clear());
    push_card("missing_cargo_toml_sha", |card| card.cargo_toml_sha.clear());
    push_card("missing_api_repo", |card| {
        card.api_refs.retain(|ref_| !ref_.contains("repo"))
    });
    push_card("missing_api_branch", |card| {
        card.api_refs.retain(|ref_| !ref_.contains("branch"))
    });
    push_card("missing_api_commits", |card| {
        card.api_refs.retain(|ref_| !ref_.contains("commits"))
    });
    push_card("missing_api_forks", |card| {
        card.api_refs.retain(|ref_| !ref_.contains("forks"))
    });
    push_card("missing_api_issues", |card| {
        card.api_refs.retain(|ref_| !ref_.contains("issues"))
    });
    push_card("missing_api_contents", |card| {
        card.api_refs.retain(|ref_| !ref_.contains("contents"))
    });
    push_card("bad_api_prefix", |card| {
        card.api_refs[0] = "github_api:wrong:repo".to_string()
    });
    push_card("missing_content_ref", |card| {
        card.api_refs
            .retain(|ref_| !ref_.starts_with("github_content:turbovec:"))
    });
    push_card("missing_swift_issue", |card| {
        card.issue_refs.retain(|ref_| !ref_.contains(":86:"))
    });
    push_card("missing_benchmark_issue", |card| {
        card.issue_refs.retain(|ref_| !ref_.contains(":65:"))
    });
    push_card("bad_release_caveat", |card| {
        card.release_caveat_ref = "release:no-caveat".to_string()
    });
    push_card("bad_owner_selection_ref", |card| {
        card.owner_selection_ref = "owner_selection:runtime".to_string()
    });
    push_card("bad_source_pin_ref", |card| {
        card.source_pin_ref = "source_pin:unverified".to_string()
    });
    push_card("bad_fork_sweep_ref", |card| {
        card.fork_sweep_ref = "fork:none".to_string()
    });
    push_card("missing_provenance", |card| card.provenance_ref.clear());
    push_card("missing_dependency_manifest", |card| {
        card.dependency_manifest_ref.clear()
    });
    push_card("missing_rollback", |card| card.rollback_ref.clear());
    push_card("missing_run_event_log", |card| {
        card.run_event_log_ref.clear()
    });
    push_card("missing_answer_packet", |card| {
        card.answer_packet_ref.clear()
    });
    push_card("missing_compatibility_fence", |card| {
        card.compatibility_fence_ref.clear()
    });
    push_card("short_summary", |card| {
        card.visible_summary = "too short".to_string()
    });
    push_card("fetch_quarantine_bytes_action", |card| {
        card.allowed_action = TurboVecSourcePinAllowedAction::FetchQuarantineBytes
    });
    push_card("adapter_wrap", |card| {
        card.allowed_action = TurboVecSourcePinAllowedAction::AdapterWrap
    });
    push_card("direct_import", |card| {
        card.allowed_action = TurboVecSourcePinAllowedAction::DirectImport
    });
    push_card("product_integration", |card| {
        card.allowed_action = TurboVecSourcePinAllowedAction::ProductIntegration
    });
    push_card("source_pin_not_metadata_only", |card| {
        card.source_pin_is_metadata_only = false
    });
    push_card("repo_fetched", |card| card.repo_fetched_or_cloned = true);
    push_card("repo_cloned_bytes", |card| {
        card.byte_ledger.cloned_repo_bytes = 1
    });
    push_card("copied_product_file", |card| {
        card.byte_ledger.copied_product_file_count = 1
    });
    push_card("external_crate_import", |card| {
        card.byte_ledger.imported_external_crate_count = 1
    });
    push_card("built_binary", |card| {
        card.byte_ledger.built_external_binary_count = 1
    });
    push_card("opened_product_index", |card| {
        card.byte_ledger.opened_product_index_bytes = 1
    });
    push_card("model_bytes_loaded", |card| {
        card.byte_ledger.model_bytes_loaded = 1
    });
    push_card("runtime_model_bytes_loaded", |card| {
        card.byte_ledger.runtime_model_bytes_loaded = 1
    });
    push_card("provider_call", |card| {
        card.byte_ledger.provider_calls_made = 1
    });
    push_card("owner_runtime_approval_granted", |card| {
        card.owner_runtime_approval_granted = true
    });
    push_card("dependency_added", |card| {
        card.dependency_added_to_product = true
    });
    push_card("source_copied", |card| card.source_copied_to_product = true);
    push_card("adapter_built", |card| card.adapter_built_or_run = true);
    push_card("benchmark_laundered", |card| {
        card.upstream_benchmark_claimed_as_product_proof = true
    });
    push_card("route_mutation", |card| card.route_mutation_allowed = true);
    push_card("context_injection", |card| {
        card.model_context_injected = true
    });
    push_card("hidden_authority", |card| {
        card.hidden_route_authority = true
    });
    push_card("hidden_cloud", |card| {
        card.hidden_cloud_fallback_allowed = true
    });
    push_card("product_promoted", |card| {
        card.product_capability_promoted = true
    });
    push_card("live_large_model", |card| {
        card.live_large_model_claimed = true
    });
    push_card("ssd_as_ram", |card| card.ssd_as_ram_claimed = true);

    let mut push_forks = |name: &str, mutate: fn(&mut Vec<TurboVecForkSweepRecord>)| {
        let mut red_forks = forks.to_vec();
        mutate(&mut red_forks);
        let passed = build_set(upstream.clone(), card.clone(), red_forks).is_err();
        results.push((name.to_string(), passed));
    };
    push_forks("too_few_forks", |forks| {
        forks.pop();
    });
    push_forks("duplicate_fork", |forks| {
        forks[1].fork_repo = forks[0].fork_repo.clone()
    });
    push_forks("archived_fork", |forks| forks[0].archived = true);
    push_forks("disabled_fork", |forks| forks[0].disabled = true);
    push_forks("fork_bad_url", |forks| {
        forks[0].fork_url = "http://example.com/fork".to_string()
    });
    push_forks("fork_bad_branch", |forks| {
        forks[0].default_branch = "dev".to_string()
    });
    push_forks("fork_bad_license", |forks| {
        forks[0].license_id = "NOASSERTION".to_string()
    });
    push_forks("fork_bad_sha", |forks| {
        forks[0].branch_sha = "short".to_string()
    });
    push_forks("matching_fork_bad_sha", |forks| {
        forks[0].branch_sha = "06155d9bf2219f0d23287d1d12b5598e676a27b1".to_string()
    });
    push_forks("lagging_fork_bad_sha", |forks| {
        forks[3].branch_sha = PINNED_REVISION.to_string()
    });
    push_forks("diverged_fork_bad_sha", |forks| {
        forks[6].branch_sha = PINNED_REVISION.to_string()
    });
    push_forks("no_matching_fork", |forks| {
        for fork in forks {
            if matches!(
                fork.disposition,
                TurboVecForkDisposition::MatchesPinnedUpstream
            ) {
                fork.disposition = TurboVecForkDisposition::LaggingKnownUpstreamCommit;
                fork.branch_sha = "06155d9bf2219f0d23287d1d12b5598e676a27b1".to_string();
            }
        }
    });
    push_forks("no_lagging_fork", |forks| {
        for fork in forks {
            if matches!(
                fork.disposition,
                TurboVecForkDisposition::LaggingKnownUpstreamCommit
            ) {
                fork.disposition = TurboVecForkDisposition::DivergedFromSampledHistory;
            }
        }
    });
    push_forks("no_diverged_fork", |forks| {
        for fork in forks {
            if matches!(
                fork.disposition,
                TurboVecForkDisposition::DivergedFromSampledHistory
            ) {
                fork.disposition = TurboVecForkDisposition::LaggingKnownUpstreamCommit;
            }
        }
    });

    let product_build_mas = TurboVecRealAdapterSourcePinProbeSet::from_parts(
        upstream.clone(),
        card.clone(),
        forks.to_vec(),
        ProductBuild::Mas,
        ProStatus::ResearchCandidate,
        TurboVecRealAdapterSourcePinStatus::PinnedMetadataOnly,
        TurboVecRealAdapterSourcePinTier::T1L1Metadata,
        organs(),
        TurboVecSourcePinPolicy::fail_closed(),
        SET_METADATA_BYTES,
        false,
    )
    .is_err();
    results.push(("product_build_mas".to_string(), product_build_mas));
    let pro_status_live = TurboVecRealAdapterSourcePinProbeSet::from_parts(
        upstream.clone(),
        card.clone(),
        forks.to_vec(),
        ProductBuild::Pro,
        ProStatus::Live,
        TurboVecRealAdapterSourcePinStatus::PinnedMetadataOnly,
        TurboVecRealAdapterSourcePinTier::T1L1Metadata,
        organs(),
        TurboVecSourcePinPolicy::fail_closed(),
        SET_METADATA_BYTES,
        false,
    )
    .is_err();
    results.push(("pro_status_live".to_string(), pro_status_live));
    let status_runtime_approved = TurboVecRealAdapterSourcePinProbeSet::from_parts(
        upstream.clone(),
        card.clone(),
        forks.to_vec(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecRealAdapterSourcePinStatus::RuntimeApprovedByLaterWitness,
        TurboVecRealAdapterSourcePinTier::T1L1Metadata,
        organs(),
        TurboVecSourcePinPolicy::fail_closed(),
        SET_METADATA_BYTES,
        false,
    )
    .is_err();
    results.push((
        "status_runtime_approved".to_string(),
        status_runtime_approved,
    ));
    let tier_t2 = TurboVecRealAdapterSourcePinProbeSet::from_parts(
        upstream.clone(),
        card.clone(),
        forks.to_vec(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecRealAdapterSourcePinStatus::PinnedMetadataOnly,
        TurboVecRealAdapterSourcePinTier::T2L2Route,
        organs(),
        TurboVecSourcePinPolicy::fail_closed(),
        SET_METADATA_BYTES,
        false,
    )
    .is_err();
    results.push(("tier_t2".to_string(), tier_t2));
    let set_product_promoted = TurboVecRealAdapterSourcePinProbeSet::from_parts(
        upstream,
        card.clone(),
        forks.to_vec(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecRealAdapterSourcePinStatus::PinnedMetadataOnly,
        TurboVecRealAdapterSourcePinTier::T1L1Metadata,
        organs(),
        TurboVecSourcePinPolicy::fail_closed(),
        SET_METADATA_BYTES,
        true,
    )
    .is_err();
    results.push(("set_product_promoted".to_string(), set_product_promoted));

    Ok(results)
}

fn organs() -> Vec<TurboVecIndexOrgan> {
    vec![
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
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
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(actual),
            unit: unit.to_string(),
        },
    );
    let operator = if name == "source_pin_address" {
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
    let pass = if name == "source_pin_address" {
        actual.starts_with(expected)
    } else {
        actual == expected
    };
    pass_per_axis.insert(name.to_string(), pass);
}

#[allow(dead_code)]
fn _keep_metrics_type_imported(_: &TurboVecRealAdapterSourcePinMetrics) {}
