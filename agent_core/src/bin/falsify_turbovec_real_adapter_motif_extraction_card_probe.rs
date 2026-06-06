//! `falsify_turbovec_real_adapter_motif_extraction_card_probe`
//!
//! Clean-room motif-card witness for `F-TurboVec-RealAdapterMotifExtractionCardProbe`.
//! It consumes the source-inspection policy gate and proves TurboVec-derived
//! API/test/benchmark/fork observations remain source-carded architecture
//! motifs only: no copied code, no product import, no runtime execution, no
//! benchmark authority, no hidden route authority, and no large-model product
//! capability claim.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    motif_extraction_digest, ProStatus, ProductBuild, TurboVecIndexOrgan, TurboVecMotifCard,
    TurboVecMotifClass, TurboVecMotifExtractionByteLedger, TurboVecMotifExtractionPolicy,
    TurboVecMotifExtractionProofRefs, TurboVecMotifExtractionStatus, TurboVecMotifExtractionTier,
    TurboVecMotifOutputMode, TurboVecRealAdapterMotifExtractionCardProbeSet, UasAddress, UasKind,
    TURBOVEC_REAL_ADAPTER_MOTIF_EXTRACTION_CARD_CURSOR,
    TURBOVEC_REAL_ADAPTER_MOTIF_EXTRACTION_CARD_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RealAdapterMotifExtractionCardProbe";
const FIXTURE_ID: &str = "turbovec_real_adapter_motif_extraction_card_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_real_adapter_motif_extraction_card_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_motif_extraction_card_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_source_inspection_policy_probe/result.json";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const RED_FIXTURE_FLOOR: u64 = 42;
const RAW_URL_PREFIX: &str =
    "https://raw.githubusercontent.com/RyanCodrai/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2/";
const ISSUE_URL_PREFIX: &str = "https://github.com/RyanCodrai/turbovec/issues/";
const PR_URL_PREFIX: &str = "https://github.com/RyanCodrai/turbovec/pull/";
const FORK_URL_PREFIX: &str = "https://github.com/";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-motif-extraction:";

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
        "{FALSIFIER_ID}: overall_pass={} motifs={} classes={} inspected_source_bytes={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["motif_count"].value,
        artifact.measurements["motif_class_count"].value,
        artifact.measurements["selected_raw_source_bytes_inspected"].value,
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
    let upstream = upstream_source_inspection_policy_address()?;
    let set = build_set(
        upstream.clone(),
        motif_cards(),
        policy(),
        proof_refs(),
        ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecMotifExtractionStatus::MotifCardsOnly,
        TurboVecMotifExtractionTier::T1L1Metadata,
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
        motif_cards().into_iter().rev().collect(),
        policy(),
        proof_refs(),
        ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecMotifExtractionStatus::MotifCardsOnly,
        TurboVecMotifExtractionTier::T1L1Metadata,
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
            "upstream_source_inspection_policy_bound",
            set.upstream_source_inspection_policy_witness_ref
                == "artifact:turbovec_real_adapter_source_inspection_policy_probe:result"
                && set
                    .upstream_source_inspection_policy_address
                    .to_string()
                    .starts_with("turbovec_real_adapter_source_inspection_policy_probe:")
                && red_pass(&red_results, "bad_upstream_cursor"),
        ),
        (
            "motif_card_coverage_bound",
            metrics.motif_count >= 10
                && metrics.motif_class_count >= 8
                && metrics.required_source_path_count >= 8
                && metrics.source_ref_count >= 10
                && red_pass(&red_results, "too_few_motifs")
                && red_pass(&red_results, "duplicate_motif_id")
                && red_pass(&red_results, "missing_input_validation_class")
                && red_pass(&red_results, "bad_source_ref"),
        ),
        (
            "api_and_stable_id_motifs_bound",
            metrics.api_shape_count >= 1
                && metrics.stable_external_id_count >= 1
                && red_pass(&red_results, "missing_api_shape")
                && red_pass(&red_results, "missing_stable_external_id"),
        ),
        (
            "filter_before_rank_and_large_model_motifs_bound",
            metrics.filter_before_rank_count >= 1
                && metrics.large_model_working_set_count >= 1
                && red_pass(&red_results, "missing_filter_before_rank")
                && red_pass(&red_results, "missing_large_model_working_set"),
        ),
        (
            "failure_and_benchmark_caveats_bound",
            metrics.input_validation_count >= 1
                && metrics.benchmark_caveat_count >= 1
                && metrics.fork_delta_count >= 1
                && red_pass(&red_results, "weak_summary")
                && red_pass(&red_results, "verbatim_source_marker")
                && red_pass(&red_results, "benchmark_authority_allowed"),
        ),
        (
            "policy_fail_closed",
            set.policy.upstream_policy_bound
                && set.policy.clean_room_only
                && set.policy.source_cards_required
                && set.policy.no_verbatim_source
                && set.policy.no_product_import
                && set.policy.no_product_dependency
                && set.policy.no_native_link_probe
                && set.policy.no_adapter_build
                && set.policy.no_benchmark_authority
                && set.policy.no_runtime_execution
                && set.policy.no_route_authority
                && set.policy.no_model_context_injection
                && set.policy.fork_deltas_non_authoritative
                && set.policy.rollback_required
                && set.policy.answer_packet_required
                && red_pass(&red_results, "policy_not_bound")
                && red_pass(&red_results, "policy_verbatim")
                && red_pass(&red_results, "policy_product_import")
                && red_pass(&red_results, "policy_dependency")
                && red_pass(&red_results, "policy_native_link")
                && red_pass(&red_results, "policy_adapter_build")
                && red_pass(&red_results, "policy_benchmark")
                && red_pass(&red_results, "policy_runtime")
                && red_pass(&red_results, "policy_route"),
        ),
        (
            "byte_scope_and_no_runtime_bound",
            metrics.selected_raw_source_bytes_inspected > 0
                && metrics.selected_raw_source_bytes_inspected
                    <= metrics.max_raw_source_bytes_allowed
                && metrics.product_files_copied == 0
                && metrics.product_dependencies_added == 0
                && metrics.native_link_probe_count == 0
                && metrics.adapter_build_count == 0
                && metrics.benchmark_run_count == 0
                && metrics.index_bytes_opened == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "source_byte_overflow")
                && red_pass(&red_results, "source_archive_fetched")
                && red_pass(&red_results, "product_file_copied")
                && red_pass(&red_results, "dependency_added")
                && red_pass(&red_results, "native_link_probe")
                && red_pass(&red_results, "adapter_build")
                && red_pass(&red_results, "benchmark_run")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "provider_call"),
        ),
        (
            "proof_surfaces_required",
            set.proof_refs.visible_summary.len() >= 520
                && red_pass(&red_results, "bad_policy_ref")
                && red_pass(&red_results, "bad_clean_room_ref")
                && red_pass(&red_results, "bad_source_card_ref")
                && red_pass(&red_results, "bad_fork_sweep_ref")
                && red_pass(&red_results, "bad_rollback_ref")
                && red_pass(&red_results, "bad_answer_packet_ref")
                && red_pass(&red_results, "weak_visible_summary"),
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
            !set.product_capability_promoted
                && !set.live_large_model_claimed
                && !set.ssd_as_ram_claimed
                && red_pass(&red_results, "product_promoted")
                && red_pass(&red_results, "product_build_mas")
                && red_pass(&red_results, "pro_status_live")
                && red_pass(&red_results, "status_runtime_candidate")
                && red_pass(&red_results, "tier_t2")
                && red_pass(&red_results, "live_large_model")
                && red_pass(&red_results, "ssd_as_ram"),
        ),
        (
            "reversed_order_address_deterministic",
            set.set_address == reversed.set_address
                && motif_extraction_digest(&set) == motif_extraction_digest(&reversed),
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
        "motif_count",
        metrics.motif_count,
        ">=",
        10,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "motif_class_count",
        metrics.motif_class_count,
        ">=",
        8,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_source_path_count",
        metrics.required_source_path_count,
        ">=",
        8,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_raw_source_bytes_inspected",
        metrics.selected_raw_source_bytes_inspected,
        ">=",
        1,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_raw_source_bytes_allowed",
        metrics.max_raw_source_bytes_allowed,
        "==",
        196_608,
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
        "count",
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
        "motif_extraction_card_address",
        &set.set_address.to_string(),
        "turbovec_real_adapter_motif_extraction_card_probe:",
        "uas_address",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        TURBOVEC_REAL_ADAPTER_MOTIF_EXTRACTION_CARD_NEXT_CURSOR,
        TURBOVEC_REAL_ADAPTER_MOTIF_EXTRACTION_CARD_NEXT_CURSOR,
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
            "kind": "clean_room_motif_only_scope",
            "detail": "Paraphrased TurboVec motif cards only. No code import, dependency insertion, adapter build, native-link probe, benchmark run, index/model/runtime/provider bytes, route/context authority, or live large-local-model product claim."
        })],
        notes: "Builds F-TurboVec-RealAdapterMotifExtractionCardProbe as a T1/L1 clean-room motif-card witness after the source-inspection policy. It mines bounded TurboVec docs/source/test/benchmark/fork metadata into paraphrased API, stable-ID, filter-before-rank, input-validation, I/O, benchmark-caveat, Swift-binding, fork-drift, and large-local-model working-set motifs for Eidos/AppColdStore and SemanticWorkingSetPlan. L2 capability and L3 user-facing model surfaces remain unchanged.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_source_inspection_policy_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec source-inspection policy has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_REAL_ADAPTER_MOTIF_EXTRACTION_CARD_CURSOR)
    {
        return Err("upstream source-inspection policy does not point at motif extraction".into());
    }
    for axis in [
        "/pass_per_axis/upstream_source_byte_manifest_bound",
        "/pass_per_axis/policy_rows_bound",
        "/pass_per_axis/future_read_and_blocked_coverage",
        "/pass_per_axis/clean_room_and_output_modes_bound",
        "/pass_per_axis/policy_fail_closed",
        "/pass_per_axis/proof_surfaces_required",
        "/pass_per_axis/bytes_remain_policy_only",
        "/pass_per_axis/no_route_context_or_hidden_authority",
        "/pass_per_axis/product_and_large_model_claims_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(
                format!("upstream source-inspection policy axis missing or false: {axis}").into(),
            );
        }
    }
    let address = value
        .pointer("/measurements/source_inspection_policy_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing source_inspection_policy_address")?;
    Ok(UasAddress::from_str(address)?)
}

#[allow(clippy::too_many_arguments)]
fn build_set(
    upstream: UasAddress,
    cards: Vec<TurboVecMotifCard>,
    policy: TurboVecMotifExtractionPolicy,
    proof_refs: TurboVecMotifExtractionProofRefs,
    ledger: TurboVecMotifExtractionByteLedger,
    product_build: ProductBuild,
    pro_status: ProStatus,
    status: TurboVecMotifExtractionStatus,
    tier: TurboVecMotifExtractionTier,
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<TurboVecRealAdapterMotifExtractionCardProbeSet, Box<dyn std::error::Error>> {
    Ok(TurboVecRealAdapterMotifExtractionCardProbeSet::from_parts(
        upstream,
        cards,
        policy,
        proof_refs,
        ledger,
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
    )?)
}

fn card(
    motif_id: &str,
    source_path: &str,
    motif_class: TurboVecMotifClass,
    output_mode: TurboVecMotifOutputMode,
    source_refs: Vec<String>,
    clean_room_summary: &str,
    epistemos_fusion: &str,
    required_falsifier: &str,
    source_bytes_inspected: u64,
) -> TurboVecMotifCard {
    TurboVecMotifCard {
        motif_id: motif_id.to_string(),
        source_path: source_path.to_string(),
        motif_class,
        output_mode,
        source_refs,
        clean_room_summary: clean_room_summary.to_string(),
        epistemos_fusion: epistemos_fusion.to_string(),
        required_falsifier: required_falsifier.to_string(),
        runtime_proof_required:
            "Shadow replay against exact AppColdStore baseline before any runtime route use."
                .to_string(),
        user_visible_proof_required:
            "AnswerPacket caveat plus RunEventLog row before any user-facing claim.".to_string(),
        rollback_ref: format!("{ROLLBACK_REF_PREFIX}{motif_id}"),
        source_bytes_inspected,
        no_verbatim_source: true,
        no_product_import: true,
        no_route_authority: true,
        benchmark_authority_denied: true,
        privacy_risk: "Allowed-set or tenant boundary leakage if the motif is implemented without SCOPE-Rex allowlist proof.".to_string(),
        stability_risk: "Adapter panic, stale cache, or shape drift if the motif becomes code without fuzz and replay proof.".to_string(),
        provenance_risk: "Upstream or fork drift can stale the source card unless pinned refs and rollback stay visible.".to_string(),
    }
}

fn motif_cards() -> Vec<TurboVecMotifCard> {
    vec![
        card(
            "api_shape_index_types",
            "docs/api.md",
            TurboVecMotifClass::ApiShape,
            TurboVecMotifOutputMode::SourceCard,
            vec![format!("{RAW_URL_PREFIX}docs/api.md")],
            "Clean-room API motif: TurboVec separates a positional compressed index from a stable external-id wrapper, which maps well to Epistemos UAS truth versus rebuildable cache storage.",
            "Epistemos should keep UAS/AppColdStore IDs as durable truth and treat any compressed index row as rebuildable cache material with explicit address mapping.",
            "F-TurboVec-CleanRoomAdapterPlan",
            8_703,
        ),
        card(
            "stable_external_ids_survive_delete",
            "turbovec/src/id_map.rs",
            TurboVecMotifClass::StableExternalId,
            TurboVecMotifOutputMode::BehaviorSpec,
            vec![format!("{RAW_URL_PREFIX}turbovec/src/id_map.rs")],
            "Clean-room behavior motif: external IDs are translated through a bidirectional table so deletion can update moved slots without changing caller-visible identity.",
            "Eidos/AppColdStore should preserve UAS external IDs above any slot-based compressed cache and reject rowid-style durable truth.",
            "F-TurboVec-IdMap-UAS-Replay",
            11_984,
        ),
        card(
            "filter_before_rank_allowlist",
            "turbovec/tests/filtering.rs",
            TurboVecMotifClass::FilterBeforeRank,
            TurboVecMotifOutputMode::TestInvariant,
            vec![
                format!("{RAW_URL_PREFIX}turbovec/tests/filtering.rs"),
                format!("{RAW_URL_PREFIX}docs/api.md"),
            ],
            "Clean-room test motif: allowed candidates must be applied before ranking so disallowed vectors never enter the candidate heap or final answer set.",
            "SCOPE-Rex/SovereignGate should compile UAS allowlists before approximate rank, not sanitize after retrieval, to protect private notes and deleted objects.",
            "F-TurboVec-Allowlist-Before-Rank-Replay",
            16_986,
        ),
        card(
            "lazy_prepare_cache_and_concurrency",
            "turbovec/src/lib.rs",
            TurboVecMotifClass::LazyPreparedCache,
            TurboVecMotifOutputMode::BehaviorSpec,
            vec![format!("{RAW_URL_PREFIX}turbovec/src/lib.rs")],
            "Clean-room behavior motif: expensive rotation, centroids, and blocked layouts can be prepared once, shared for concurrent reads, and invalidated on mutation.",
            "ActiveAssembly should model cache preparation as an explicit lease with cancellation and invalidation, letting large local models receive smaller hot working sets.",
            "F-TurboVec-PreparedCache-Lease",
            31_155,
        ),
        card(
            "input_validation_no_silent_poison",
            "turbovec/tests/input_validation.rs",
            TurboVecMotifClass::InputValidation,
            TurboVecMotifOutputMode::TestInvariant,
            vec![
                format!("{RAW_URL_PREFIX}turbovec/tests/input_validation.rs"),
                format!("{RAW_URL_PREFIX}turbovec/src/lib.rs"),
            ],
            "Clean-room failure motif: non-finite and extreme coordinates must reject before they can poison scales, unreachable slots, or top-k ranking.",
            "Every Epistemos compressed-retrieval adapter should carry finite-value gates, dimensionality checks, and rollback so bad embeddings cannot corrupt AppColdStore cache state.",
            "F-TurboVec-EmbeddingInputFiniteGate",
            7_686,
        ),
        card(
            "io_format_version_rebuild_hint",
            "turbovec/src/io.rs",
            TurboVecMotifClass::CrashSafeIo,
            TurboVecMotifOutputMode::BehaviorSpec,
            vec![format!("{RAW_URL_PREFIX}turbovec/src/io.rs")],
            "Clean-room I/O motif: persisted compressed indexes need magic/version checks, explicit incompatible-version rejection, and rebuild hints rather than silent load.",
            "ColdStore/AppColdStore should treat compressed indexes as versioned cache artifacts with rebuild-from-truth semantics and AnswerPacket-visible corruption fallback.",
            "F-TurboVec-CacheFormat-VersionFence",
            9_855,
        ),
        card(
            "benchmark_recall_not_authority",
            "benchmarks/suite/recall_d1536_4bit.py",
            TurboVecMotifClass::BenchmarkCaveat,
            TurboVecMotifOutputMode::BenchmarkCaveat,
            vec![
                format!("{RAW_URL_PREFIX}benchmarks/suite/recall_d1536_4bit.py"),
                format!("{RAW_URL_PREFIX}benchmarks/suite/speed_d1536_4bit_arm_mt.py"),
            ],
            "Clean-room benchmark motif: recall and speed scripts define candidate measurement shapes, but their data, baselines, and hardware do not become Epistemos route authority.",
            "Use these as shadow-benchmark schema hints only; Epistemos still needs exact AppColdStore baseline replay, privacy allowlists, latency, memory, and AnswerPacket caveats.",
            "F-TurboVec-HeldOutReplay-BenchmarkCaveat",
            4_399,
        ),
        card(
            "swift_binding_uniffi_risk",
            "issue/86",
            TurboVecMotifClass::SwiftBindingRisk,
            TurboVecMotifOutputMode::ForkDelta,
            vec![format!("{ISSUE_URL_PREFIX}86")],
            "Clean-room issue motif: a Swift/macOS binding proposal favors wrapping the Rust core over a native Swift hot path and calls out concurrency, error, and packaging surfaces.",
            "Epistemos should keep this Pro Research until MAS boundary, FFI ownership, no-subprocess, cancellation, and no-hidden-fallback witnesses prove the bridge.",
            "F-TurboVec-SwiftBinding-MASBoundary",
            2_048,
        ),
        card(
            "public_io_api_gap",
            "issue/70",
            TurboVecMotifClass::CrashSafeIo,
            TurboVecMotifOutputMode::ForkDelta,
            vec![format!("{ISSUE_URL_PREFIX}70")],
            "Clean-room issue motif: embedders want in-memory read/write and construction-from-parts APIs to avoid temporary file round trips and to fit host storage pages.",
            "ColdStream and AppColdStore should prefer buffer-backed serialization witnesses before any adapter forces tmpfile I/O or platform-specific native link behavior.",
            "F-TurboVec-BufferBackedIo-Card",
            2_048,
        ),
        card(
            "fork_drift_and_release_audit",
            "pull/83",
            TurboVecMotifClass::ForkDrift,
            TurboVecMotifOutputMode::ForkDelta,
            vec![
                format!("{PR_URL_PREFIX}83"),
                format!("{PR_URL_PREFIX}84"),
                format!("{FORK_URL_PREFIX}AKHtun/turbovec-wecos"),
            ],
            "Clean-room fork motif: recent upstream integration and release work plus same-day forks mean Epistemos must pin revisions and classify fork deltas before any adapter plan.",
            "The motif feeds a source-card diff ledger so large local model retrieval cannot inherit stale upstream/fork behavior or unreviewed integration assumptions.",
            "F-TurboVec-ForkDelta-SourceCard",
            4_096,
        ),
        card(
            "large_model_working_set_retrieval",
            "README.md",
            TurboVecMotifClass::LargeModelWorkingSet,
            TurboVecMotifOutputMode::ArchitectureFusion,
            vec![format!("{RAW_URL_PREFIX}README.md")],
            "Clean-room architecture motif: compressed local retrieval can reduce memory pressure and feed higher-signal context, but only as rebuildable cache, never durable truth.",
            "For Gemma 4 QAT, Qwen, Granite, and 70B-class cold assemblies, this motivates a semantic working-set compiler that shrinks hot context under visible proof.",
            "F-TurboVec-WorkingSetCompiler-Replay",
            13_593,
        ),
    ]
}

fn policy() -> TurboVecMotifExtractionPolicy {
    TurboVecMotifExtractionPolicy::fail_closed()
}

fn proof_refs() -> TurboVecMotifExtractionProofRefs {
    TurboVecMotifExtractionProofRefs {
        source_inspection_policy_ref:
            "artifact:turbovec_real_adapter_source_inspection_policy_probe:result".to_string(),
        provenance_ref: "provenance:turbovec-motif-extraction:pinned-source-refs".to_string(),
        clean_room_ref: "clean_room:turbovec-motif-extraction:no-verbatim".to_string(),
        source_card_ref: "source_card:turbovec-motif-extraction:motif-pack".to_string(),
        fork_sweep_ref: "fork_sweep:turbovec-motif-extraction:public-forks-and-issues".to_string(),
        no_product_graph_ref: "no_product_graph:turbovec-motif-extraction:no-import".to_string(),
        rollback_ref: "rollback:turbovec-motif-extraction:motif-pack".to_string(),
        run_event_log_ref: "run_event_log:turbovec-motif-extraction:motif-pack".to_string(),
        answer_packet_ref: "answer_packet:turbovec-motif-extraction:motif-pack".to_string(),
        compatibility_fence_ref: "compat:turbovec-motif-extraction:policy-v1".to_string(),
        benchmark_caveat_ref: "benchmark_caveat:turbovec-motif-extraction:shadow-only".to_string(),
        visible_summary: "clean-room TurboVec motif extraction for large local model working sets. This witness source-cards paraphrased API, stable-ID, filter-before-rank, input-validation, I/O, benchmark-caveat, Swift-binding, fork-drift, and working-set motifs for Eidos/AppColdStore and SemanticWorkingSetPlan. It carries rollback, RunEventLog, AnswerPacket, compatibility and benchmark caveats, no hidden route authority, no live dense 70B claim, no product import, no runtime execution, no benchmark authority, and no product capability promotion. The motifs may guide future falsifiers and adapter cards only; they cannot choose RuntimeRouter/System G routes, inject context into Gemma/QAT/Qwen/Granite lanes, or represent measured compressed-retrieval quality.".to_string(),
    }
}

fn ledger() -> TurboVecMotifExtractionByteLedger {
    TurboVecMotifExtractionByteLedger::selected_source_only()
}

fn red_fixture_results(upstream: &UasAddress) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    push_case(&mut results, "bad_upstream_cursor", || {
        let bad = UasAddress::new(UasKind::Other("wrong_cursor".to_string()), b"abc", 1);
        default_with_upstream(bad).is_err()
    });
    push_case(&mut results, "too_few_motifs", || {
        let mut cards = motif_cards();
        cards.truncate(4);
        with_cards(upstream.clone(), cards).is_err()
    });
    push_case(&mut results, "duplicate_motif_id", || {
        let mut cards = motif_cards();
        cards[1].motif_id = cards[0].motif_id.clone();
        with_cards(upstream.clone(), cards).is_err()
    });
    push_case(&mut results, "missing_input_validation_class", || {
        let mut cards = motif_cards();
        cards.retain(|card| card.motif_class != TurboVecMotifClass::InputValidation);
        with_cards(upstream.clone(), cards).is_err()
    });
    for (name, class) in [
        ("missing_api_shape", TurboVecMotifClass::ApiShape),
        (
            "missing_stable_external_id",
            TurboVecMotifClass::StableExternalId,
        ),
        (
            "missing_filter_before_rank",
            TurboVecMotifClass::FilterBeforeRank,
        ),
        (
            "missing_large_model_working_set",
            TurboVecMotifClass::LargeModelWorkingSet,
        ),
    ] {
        push_case(&mut results, name, || {
            let mut cards = motif_cards();
            cards.retain(|card| card.motif_class != class);
            with_cards(upstream.clone(), cards).is_err()
        });
    }
    for (name, mutate) in motif_mutators() {
        push_case(&mut results, name, || {
            let mut cards = motif_cards();
            mutate(&mut cards);
            with_cards(upstream.clone(), cards).is_err()
        });
    }
    for (name, mutate) in policy_mutators() {
        push_case(&mut results, name, || {
            let mut policy = policy();
            mutate(&mut policy);
            with_policy(upstream.clone(), policy).is_err()
        });
    }
    for (name, mutate) in ledger_mutators() {
        push_case(&mut results, name, || {
            let mut ledger = ledger();
            mutate(&mut ledger);
            with_ledger(upstream.clone(), ledger).is_err()
        });
    }
    for (name, mutate) in proof_mutators() {
        push_case(&mut results, name, || {
            let mut proof_refs = proof_refs();
            mutate(&mut proof_refs);
            with_proof(upstream.clone(), proof_refs).is_err()
        });
    }
    for (name, product_build, pro_status, status, tier, flag) in claim_cases() {
        push_case(&mut results, name, || {
            build_set(
                upstream.clone(),
                motif_cards(),
                policy(),
                proof_refs(),
                ledger(),
                product_build,
                pro_status,
                status,
                tier,
                matches!(flag, ClaimFlag::ProductPromotion),
                matches!(flag, ClaimFlag::RouteMutation),
                matches!(flag, ClaimFlag::ContextInjection),
                matches!(flag, ClaimFlag::HiddenAuthority),
                matches!(flag, ClaimFlag::HiddenCloud),
                matches!(flag, ClaimFlag::LiveLargeModel),
                matches!(flag, ClaimFlag::SsdAsRam),
            )
            .is_err()
        });
    }
    results
}

type MotifMutator = fn(&mut Vec<TurboVecMotifCard>);
type PolicyMutator = fn(&mut TurboVecMotifExtractionPolicy);
type LedgerMutator = fn(&mut TurboVecMotifExtractionByteLedger);
type ProofMutator = fn(&mut TurboVecMotifExtractionProofRefs);

fn motif_mutators() -> Vec<(&'static str, MotifMutator)> {
    vec![
        ("bad_source_ref", |cards| {
            cards[0].source_refs = vec!["https://example.com".to_string()]
        }),
        ("weak_summary", |cards| {
            cards[0].clean_room_summary = "too short".to_string()
        }),
        ("verbatim_source_marker", |cards| {
            cards[0].clean_room_summary = "fn copied_source() {}".to_string()
        }),
        ("benchmark_authority_allowed", |cards| {
            cards[0].benchmark_authority_denied = false
        }),
        ("product_import_allowed", |cards| {
            cards[0].no_product_import = false
        }),
        ("route_authority_allowed", |cards| {
            cards[0].no_route_authority = false
        }),
        ("blocked_path", |cards| {
            cards[0].source_path = "turbovec/build.rs".to_string()
        }),
        ("unsafe_path", |cards| {
            cards[0].source_path = "../README.md".to_string()
        }),
        ("bad_rollback_ref", |cards| {
            cards[0].rollback_ref = "rollback:wrong".to_string()
        }),
        ("bad_motif_id", |cards| {
            cards[0].motif_id = "Bad Id".to_string()
        }),
    ]
}

fn policy_mutators() -> Vec<(&'static str, PolicyMutator)> {
    vec![
        ("policy_not_bound", |p| p.upstream_policy_bound = false),
        ("policy_verbatim", |p| p.no_verbatim_source = false),
        ("policy_product_import", |p| p.no_product_import = false),
        ("policy_dependency", |p| p.no_product_dependency = false),
        ("policy_native_link", |p| p.no_native_link_probe = false),
        ("policy_adapter_build", |p| p.no_adapter_build = false),
        ("policy_benchmark", |p| p.no_benchmark_authority = false),
        ("policy_runtime", |p| p.no_runtime_execution = false),
        ("policy_route", |p| p.no_route_authority = false),
    ]
}

fn ledger_mutators() -> Vec<(&'static str, LedgerMutator)> {
    vec![
        ("source_byte_overflow", |l| {
            l.selected_raw_source_bytes_inspected = 196_609
        }),
        ("source_archive_fetched", |l| {
            l.source_archive_bytes_fetched = 1
        }),
        ("product_file_copied", |l| l.product_files_copied = 1),
        ("dependency_added", |l| l.product_dependencies_added = 1),
        ("native_link_probe", |l| l.native_link_probe_count = 1),
        ("adapter_build", |l| l.adapter_build_count = 1),
        ("benchmark_run", |l| l.benchmark_run_count = 1),
        ("model_bytes_loaded", |l| l.model_bytes_loaded = 1),
        ("provider_call", |l| l.provider_calls_made = 1),
    ]
}

fn proof_mutators() -> Vec<(&'static str, ProofMutator)> {
    vec![
        ("bad_policy_ref", |p| {
            p.source_inspection_policy_ref = "artifact:wrong".to_string()
        }),
        ("bad_clean_room_ref", |p| {
            p.clean_room_ref = "clean:wrong".to_string()
        }),
        ("bad_source_card_ref", |p| {
            p.source_card_ref = "source:wrong".to_string()
        }),
        ("bad_fork_sweep_ref", |p| {
            p.fork_sweep_ref = "fork:wrong".to_string()
        }),
        ("bad_rollback_ref", |p| {
            p.rollback_ref = "rollback:wrong".to_string()
        }),
        ("bad_answer_packet_ref", |p| {
            p.answer_packet_ref = "answer:wrong".to_string()
        }),
        ("weak_visible_summary", |p| {
            p.visible_summary = "too short".to_string()
        }),
    ]
}

// UAS: red-fixture claim axis for TurboVec clean-room motif extraction.
// Plane: Verification.
// Residency: metadata-only falsifier helper; no product or runtime bytes.
#[derive(Clone, Copy)]
enum ClaimFlag {
    None,
    ProductPromotion,
    RouteMutation,
    ContextInjection,
    HiddenAuthority,
    HiddenCloud,
    LiveLargeModel,
    SsdAsRam,
}

#[allow(clippy::type_complexity)]
fn claim_cases() -> Vec<(
    &'static str,
    ProductBuild,
    ProStatus,
    TurboVecMotifExtractionStatus,
    TurboVecMotifExtractionTier,
    ClaimFlag,
)> {
    vec![
        (
            "product_build_mas",
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            ClaimFlag::None,
        ),
        (
            "pro_status_live",
            ProductBuild::Pro,
            ProStatus::Live,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            ClaimFlag::None,
        ),
        (
            "status_runtime_candidate",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::RuntimeCandidate,
            TurboVecMotifExtractionTier::T1L1Metadata,
            ClaimFlag::None,
        ),
        (
            "tier_t2",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T2L2Route,
            ClaimFlag::None,
        ),
        (
            "product_promoted",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            ClaimFlag::ProductPromotion,
        ),
        (
            "route_mutation",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            ClaimFlag::RouteMutation,
        ),
        (
            "context_injection",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            ClaimFlag::ContextInjection,
        ),
        (
            "hidden_authority",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            ClaimFlag::HiddenAuthority,
        ),
        (
            "hidden_cloud",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            ClaimFlag::HiddenCloud,
        ),
        (
            "live_large_model",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            ClaimFlag::LiveLargeModel,
        ),
        (
            "ssd_as_ram",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            ClaimFlag::SsdAsRam,
        ),
    ]
}

fn default_with_upstream(
    upstream: UasAddress,
) -> Result<TurboVecRealAdapterMotifExtractionCardProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        motif_cards(),
        policy(),
        proof_refs(),
        ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecMotifExtractionStatus::MotifCardsOnly,
        TurboVecMotifExtractionTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn with_cards(
    upstream: UasAddress,
    cards: Vec<TurboVecMotifCard>,
) -> Result<TurboVecRealAdapterMotifExtractionCardProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        cards,
        policy(),
        proof_refs(),
        ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecMotifExtractionStatus::MotifCardsOnly,
        TurboVecMotifExtractionTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn with_policy(
    upstream: UasAddress,
    policy: TurboVecMotifExtractionPolicy,
) -> Result<TurboVecRealAdapterMotifExtractionCardProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        motif_cards(),
        policy,
        proof_refs(),
        ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecMotifExtractionStatus::MotifCardsOnly,
        TurboVecMotifExtractionTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn with_ledger(
    upstream: UasAddress,
    ledger: TurboVecMotifExtractionByteLedger,
) -> Result<TurboVecRealAdapterMotifExtractionCardProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        motif_cards(),
        policy(),
        proof_refs(),
        ledger,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecMotifExtractionStatus::MotifCardsOnly,
        TurboVecMotifExtractionTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn with_proof(
    upstream: UasAddress,
    proof_refs: TurboVecMotifExtractionProofRefs,
) -> Result<TurboVecRealAdapterMotifExtractionCardProbeSet, Box<dyn std::error::Error>> {
    build_set(
        upstream,
        motif_cards(),
        policy(),
        proof_refs,
        ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecMotifExtractionStatus::MotifCardsOnly,
        TurboVecMotifExtractionTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
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
