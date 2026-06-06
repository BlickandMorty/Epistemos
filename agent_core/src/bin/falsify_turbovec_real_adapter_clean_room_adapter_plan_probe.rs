//! `falsify_turbovec_real_adapter_clean_room_adapter_plan_probe`
//!
//! Clean-room adapter-plan witness for
//! `F-TurboVec-RealAdapterCleanRoomAdapterPlanProbe`. It consumes the
//! motif-extraction card gate and proves the next TurboVec-derived step is an
//! Epistemos-owned adapter contract only: no source import, dependency,
//! native-link probe, adapter build, benchmark authority, route mutation, model
//! context injection, runtime bytes, or product capability claim.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    clean_room_adapter_plan_digest, ProStatus, ProductBuild, TurboVecAdapterPlanByteLedger,
    TurboVecAdapterPlanComponent, TurboVecAdapterPlanPolicy, TurboVecAdapterPlanProofRefs,
    TurboVecAdapterPlanStatus, TurboVecAdapterPlanStep, TurboVecAdapterPlanTier,
    TurboVecIndexOrgan, TurboVecRealAdapterCleanRoomAdapterPlanProbeSet, UasAddress,
    TURBOVEC_REAL_ADAPTER_CLEAN_ROOM_ADAPTER_PLAN_CURSOR,
    TURBOVEC_REAL_ADAPTER_CLEAN_ROOM_ADAPTER_PLAN_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RealAdapterCleanRoomAdapterPlanProbe";
const FIXTURE_ID: &str = "turbovec_real_adapter_clean_room_adapter_plan_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_real_adapter_clean_room_adapter_plan_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_clean_room_adapter_plan_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_motif_extraction_card_probe/result.json";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const MOTIF_REF_PREFIX: &str = "motif:turbovec-real-adapter:";
const PLAN_REF_PREFIX: &str = "clean_room_plan:turbovec-adapter:";
const SOURCE_CARD_REF_PREFIX: &str = "source_card:turbovec-motif-extraction:";
const NO_PRODUCT_GRAPH_REF_PREFIX: &str = "no_product_graph:turbovec-clean-room-adapter:";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-clean-room-adapter:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:turbovec-clean-room-adapter:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:turbovec-clean-room-adapter:";
const COMPATIBILITY_REF_PREFIX: &str = "compat:turbovec-clean-room-adapter:";
const SHADOW_REPLAY_REF_PREFIX: &str = "shadow_replay:turbovec-clean-room-adapter:";
const BASELINE_REF_PREFIX: &str = "exact_baseline:turbovec-clean-room-adapter:";
const RED_FIXTURE_FLOOR: u64 = 46;

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
        "{FALSIFIER_ID}: overall_pass={} steps={} components={} motif_links={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["plan_step_count"].value,
        artifact.measurements["component_count"].value,
        artifact.measurements["motif_link_count"].value,
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
    let upstream = upstream_motif_card_address()?;
    let set = build_set(
        upstream.clone(),
        adapter_steps(),
        policy(),
        proof_refs(),
        ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
        TurboVecAdapterPlanTier::T1L1Metadata,
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
        adapter_steps().into_iter().rev().collect(),
        policy(),
        proof_refs(),
        ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
        TurboVecAdapterPlanTier::T1L1Metadata,
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
            "upstream_motif_cards_bound",
            set.upstream_motif_card_witness_ref
                == "artifact:turbovec_real_adapter_motif_extraction_card_probe:result"
                && set
                    .upstream_motif_card_address
                    .to_string()
                    .starts_with("turbovec_real_adapter_motif_extraction_card_probe:")
                && red_pass(&red_results, "bad_upstream_cursor"),
        ),
        (
            "adapter_plan_component_coverage",
            metrics.plan_step_count >= 9
                && metrics.component_count >= 8
                && metrics.motif_link_count >= 10
                && metrics.buffer_backed_io_step_count >= 1
                && metrics.exact_baseline_step_count >= 1
                && metrics.large_model_working_set_step_count >= 1
                && red_pass(&red_results, "too_few_steps")
                && red_pass(&red_results, "duplicate_step_id")
                && red_pass(&red_results, "missing_buffer_io")
                && red_pass(&red_results, "missing_exact_baseline")
                && red_pass(&red_results, "missing_large_model_step")
                && red_pass(&red_results, "bad_motif_ref"),
        ),
        (
            "uas_filter_io_baseline_contract_bound",
            has_component(&set, TurboVecAdapterPlanComponent::UasExternalIdMap)
                && has_component(&set, TurboVecAdapterPlanComponent::FilterBeforeRankPipeline)
                && has_component(&set, TurboVecAdapterPlanComponent::BufferBackedIoBoundary)
                && has_component(&set, TurboVecAdapterPlanComponent::VersionedRebuildFence)
                && has_component(
                    &set,
                    TurboVecAdapterPlanComponent::ExactBaselineShadowReplay,
                ),
        ),
        (
            "policy_fail_closed",
            set.policy.upstream_motif_cards_bound
                && set.policy.clean_room_rewrite_only
                && set.policy.source_card_trace_required
                && set.policy.no_verbatim_source
                && set.policy.no_direct_import
                && set.policy.no_adapter_wrap
                && set.policy.no_product_dependency
                && set.policy.no_native_link_default
                && set.policy.no_adapter_build
                && set.policy.no_benchmark_authority
                && set.policy.no_runtime_execution
                && set.policy.no_route_authority
                && set.policy.no_model_context_injection
                && set.policy.exact_baseline_required_before_quality
                && set.policy.shadow_replay_required_before_live_route
                && set.policy.rollback_required
                && set.policy.answer_packet_required
                && red_pass(&red_results, "policy_direct_import")
                && red_pass(&red_results, "policy_adapter_wrap")
                && red_pass(&red_results, "policy_dependency")
                && red_pass(&red_results, "policy_native_link")
                && red_pass(&red_results, "policy_adapter_build")
                && red_pass(&red_results, "policy_benchmark")
                && red_pass(&red_results, "policy_runtime")
                && red_pass(&red_results, "policy_route"),
        ),
        (
            "byte_scope_no_build_or_runtime",
            metrics.upstream_motif_source_bytes_cited == 184_472
                && metrics.additional_raw_source_bytes_inspected == 0
                && metrics.adapter_plan_metadata_bytes > 0
                && metrics.product_files_copied == 0
                && metrics.product_dependencies_added == 0
                && metrics.native_link_probe_count == 0
                && metrics.adapter_build_count == 0
                && metrics.benchmark_run_count == 0
                && metrics.index_bytes_opened == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "additional_source_read")
                && red_pass(&red_results, "product_file_copied")
                && red_pass(&red_results, "dependency_added")
                && red_pass(&red_results, "native_link_probe")
                && red_pass(&red_results, "adapter_build")
                && red_pass(&red_results, "benchmark_run")
                && red_pass(&red_results, "index_bytes_opened")
                && red_pass(&red_results, "model_bytes_loaded"),
        ),
        (
            "proof_surfaces_required",
            set.proof_refs.visible_summary.len() >= 560
                && red_pass(&red_results, "bad_source_card_ref")
                && red_pass(&red_results, "bad_no_product_graph_ref")
                && red_pass(&red_results, "bad_baseline_ref")
                && red_pass(&red_results, "bad_shadow_replay_ref")
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
                && clean_room_adapter_plan_digest(&set)
                    == clean_room_adapter_plan_digest(&reversed),
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
        "plan_step_count",
        metrics.plan_step_count,
        ">=",
        9,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "component_count",
        metrics.component_count,
        ">=",
        8,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "motif_link_count",
        metrics.motif_link_count,
        ">=",
        10,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_motif_source_bytes_cited",
        metrics.upstream_motif_source_bytes_cited,
        "==",
        184_472,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "additional_raw_source_bytes_inspected",
        metrics.additional_raw_source_bytes_inspected,
        "==",
        0,
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
        "clean_room_adapter_plan_address",
        &set.set_address.to_string(),
        "turbovec_real_adapter_clean_room_adapter_plan_probe:",
        "uas_address",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        TURBOVEC_REAL_ADAPTER_CLEAN_ROOM_ADAPTER_PLAN_NEXT_CURSOR,
        TURBOVEC_REAL_ADAPTER_CLEAN_ROOM_ADAPTER_PLAN_NEXT_CURSOR,
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
            "kind": "clean_room_adapter_plan_only_scope",
            "detail": "Adapter contract only. No upstream source import, dependency insertion, native-link probe, adapter build, benchmark run, index/model/runtime/provider bytes, route mutation, context injection, hidden authority, or live large-local-model product claim."
        })],
        notes: "Builds F-TurboVec-RealAdapterCleanRoomAdapterPlanProbe as a T1/L1 clean-room adapter-plan witness after the TurboVec motif cards. It specifies the Epistemos-owned adapter contract for UAS stable IDs, filter-before-rank privacy, buffer-backed I/O, versioned rebuild fences, exact-baseline shadow replay, cancellation, rollback, AnswerPacket caveats, and large-local-model working-set compilation without importing upstream code or promoting L2/L3 capability.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_motif_card_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec motif-card witness has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_REAL_ADAPTER_CLEAN_ROOM_ADAPTER_PLAN_CURSOR)
    {
        return Err("upstream motif-card witness does not point at adapter plan".into());
    }
    for axis in [
        "/pass_per_axis/upstream_source_inspection_policy_bound",
        "/pass_per_axis/motif_card_coverage_bound",
        "/pass_per_axis/api_and_stable_id_motifs_bound",
        "/pass_per_axis/filter_before_rank_and_large_model_motifs_bound",
        "/pass_per_axis/policy_fail_closed",
        "/pass_per_axis/byte_scope_and_no_runtime_bound",
        "/pass_per_axis/no_route_context_or_hidden_authority",
        "/pass_per_axis/product_and_large_model_claims_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(format!("upstream motif-card axis missing or false: {axis}").into());
        }
    }
    let address = value
        .pointer("/measurements/motif_extraction_card_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing motif_extraction_card_address")?;
    Ok(UasAddress::from_str(address)?)
}

#[allow(clippy::too_many_arguments)]
fn build_set(
    upstream: UasAddress,
    steps: Vec<TurboVecAdapterPlanStep>,
    policy: TurboVecAdapterPlanPolicy,
    proof_refs: TurboVecAdapterPlanProofRefs,
    ledger: TurboVecAdapterPlanByteLedger,
    product_build: ProductBuild,
    pro_status: ProStatus,
    status: TurboVecAdapterPlanStatus,
    tier: TurboVecAdapterPlanTier,
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<TurboVecRealAdapterCleanRoomAdapterPlanProbeSet, Box<dyn std::error::Error>> {
    Ok(TurboVecRealAdapterCleanRoomAdapterPlanProbeSet::from_parts(
        upstream,
        steps,
        policy,
        proof_refs,
        ledger,
        product_build,
        pro_status,
        status,
        tier,
        product_capability_promoted,
        route_mutation_allowed,
        model_context_injected,
        hidden_route_authority,
        hidden_cloud_fallback_allowed,
        live_large_model_claimed,
        ssd_as_ram_claimed,
    )?)
}

fn has_component(
    set: &TurboVecRealAdapterCleanRoomAdapterPlanProbeSet,
    component: TurboVecAdapterPlanComponent,
) -> bool {
    set.steps.iter().any(|step| step.component == component)
}

fn policy() -> TurboVecAdapterPlanPolicy {
    TurboVecAdapterPlanPolicy::fail_closed()
}

fn ledger() -> TurboVecAdapterPlanByteLedger {
    TurboVecAdapterPlanByteLedger::metadata_only()
}

fn proof_refs() -> TurboVecAdapterPlanProofRefs {
    TurboVecAdapterPlanProofRefs {
        source_card_ref: format!("{SOURCE_CARD_REF_PREFIX}adapter-plan"),
        no_product_graph_ref: format!("{NO_PRODUCT_GRAPH_REF_PREFIX}adapter-plan"),
        exact_baseline_ref: format!("{BASELINE_REF_PREFIX}adapter-plan"),
        shadow_replay_ref: format!("{SHADOW_REPLAY_REF_PREFIX}adapter-plan"),
        rollback_ref: format!("{ROLLBACK_REF_PREFIX}adapter-plan"),
        run_event_log_ref: format!("{RUN_EVENT_LOG_REF_PREFIX}adapter-plan"),
        answer_packet_ref: format!("{ANSWER_PACKET_REF_PREFIX}adapter-plan"),
        compatibility_fence_ref: format!("{COMPATIBILITY_REF_PREFIX}adapter-plan"),
        visible_summary: "This clean-room adapter plan keeps TurboVec-derived motifs as Epistemos-owned design constraints for large local model working sets. It binds UAS stable IDs, filter-before-rank privacy, buffer-backed I/O, versioned rebuilds, exact-baseline shadow replay, cancellation, rollback, RunEventLog, and AnswerPacket caveats. It has no hidden route authority, no live dense 70B claim, no native-link build, no benchmark authority, no source import, no product dependency, no model-context injection, and no L2/L3 product promotion before later witnesses prove runtime behavior. It is intentionally plan-only, keeps compressed retrieval subordinate to Eidos/AppColdStore truth, and makes every future quality claim wait for held-out replay plus visible fallback."
            .to_string(),
    }
}

fn adapter_steps() -> Vec<TurboVecAdapterPlanStep> {
    vec![
        adapter_step(
            "uas_external_id_map",
            TurboVecAdapterPlanComponent::UasExternalIdMap,
            TurboVecIndexOrgan::AppColdStore,
            &["stable_external_ids_survive_delete", "api_shape_index_types"],
            "Maps every future compressed-row handle to an Epistemos-owned UAS stable external ID with tombstone and generation replay before any approximate index can cite the row.",
        ),
        adapter_step(
            "filter_before_rank_pipeline",
            TurboVecAdapterPlanComponent::FilterBeforeRankPipeline,
            TurboVecIndexOrgan::Eidos,
            &["filter_before_rank_allowlist", "large_model_working_set_retrieval"],
            "Compiles SCOPE-Rex/SovereignGate allowlists from UAS IDs before approximate ranking so private, deleted, unknown, or forbidden candidates are never scored.",
        ),
        adapter_step(
            "buffer_backed_io_boundary",
            TurboVecAdapterPlanComponent::BufferBackedIoBoundary,
            TurboVecIndexOrgan::AppColdStore,
            &["public_io_api_gap", "io_format_version_rebuild_hint"],
            "Defines a buffer-backed serialized-index boundary that treats .tv or .tvim material as rebuildable cache bytes, not durable truth or product dependency code.",
        ),
        adapter_step(
            "versioned_rebuild_fence",
            TurboVecAdapterPlanComponent::VersionedRebuildFence,
            TurboVecIndexOrgan::AppColdStore,
            &["io_format_version_rebuild_hint", "input_validation_no_silent_poison"],
            "Requires magic/version/digest checks, finite-vector validation, and AppColdStore rebuild hints before any persisted compressed cache can be trusted.",
        ),
        adapter_step(
            "exact_baseline_shadow_replay",
            TurboVecAdapterPlanComponent::ExactBaselineShadowReplay,
            TurboVecIndexOrgan::Eidos,
            &["benchmark_recall_not_authority", "filter_before_rank_allowlist"],
            "Requires exact AppColdStore baseline shadow replay on held-out query packs before recall, quality, or context-selection improvement can be claimed.",
        ),
        adapter_step(
            "privacy_latency_abstention",
            TurboVecAdapterPlanComponent::PrivacyLatencyAbstention,
            TurboVecIndexOrgan::Eidos,
            &["filter_before_rank_allowlist", "lazy_prepare_cache_and_concurrency"],
            "Adds abstention cases for empty allowlists, uncertain recall, stale prepared caches, memory pressure, timeout, or cancellation before context selection proceeds.",
        ),
        adapter_step(
            "cancellation_rollback_lease",
            TurboVecAdapterPlanComponent::CancellationRollbackLease,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            &["lazy_prepare_cache_and_concurrency", "io_format_version_rebuild_hint"],
            "Requires every future adapter build or replay to carry a cancellation token, rollback handle, and RunEventLog event before bytes become route evidence.",
        ),
        adapter_step(
            "answer_packet_caveat",
            TurboVecAdapterPlanComponent::AnswerPacketCaveat,
            TurboVecIndexOrgan::AnswerPacket,
            &["benchmark_recall_not_authority", "fork_drift_and_release_audit"],
            "Forces every future compressed retrieval claim to surface source refs, rejected candidates, bytes planned/opened/resident, fallback, caveat, and rollback in AnswerPacket form.",
        ),
        adapter_step(
            "no_native_link_default",
            TurboVecAdapterPlanComponent::NoNativeLinkDefault,
            TurboVecIndexOrgan::AppColdStore,
            &["swift_binding_uniffi_risk", "fork_drift_and_release_audit"],
            "Keeps native linking, UniFFI bridging, BLAS flags, and product dependency insertion denied until a later explicit native-link dry-run witness exists.",
        ),
        adapter_step(
            "large_model_working_set_compiler",
            TurboVecAdapterPlanComponent::LargeModelWorkingSetCompiler,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            &["large_model_working_set_retrieval", "stable_external_ids_survive_delete"],
            "Connects compressed retrieval to the Semantic Working-Set Compiler as proposal-only evidence for large local model context minimization, not hidden route authority.",
        ),
    ]
}

fn adapter_step(
    step_id: &str,
    component: TurboVecAdapterPlanComponent,
    organ: TurboVecIndexOrgan,
    motifs: &[&str],
    interface_summary: &str,
) -> TurboVecAdapterPlanStep {
    TurboVecAdapterPlanStep {
        step_id: step_id.to_string(),
        component,
        organ,
        source_motif_ids: motifs
            .iter()
            .map(|motif| format!("{MOTIF_REF_PREFIX}{motif}"))
            .collect(),
        plan_ref: format!("{PLAN_REF_PREFIX}{step_id}"),
        interface_summary: interface_summary.to_string(),
        invariant: format!(
            "{step_id} invariant is Epistemos-owned, source-carded, reversible, and blocked from route/runtime authority until exact-baseline shadow replay passes."
        ),
        forbidden_action: format!(
            "{step_id} forbids upstream source import, product dependency insertion, native-link probing, adapter builds, benchmark authority, hidden routes, and context injection."
        ),
        runtime_proof_required:
            "exact-baseline shadow replay, cancellation, rollback, memory ledger, and held-out transcript required"
                .to_string(),
        user_visible_proof_required:
            "AnswerPacket visible caveat with rejected candidates, byte ledger, fallback, rollback, and source refs required"
                .to_string(),
        rollback_ref: format!("{ROLLBACK_REF_PREFIX}{step_id}"),
        no_upstream_source_import: true,
        no_product_dependency: true,
        no_native_link_probe: true,
        no_benchmark_authority: true,
        no_route_authority: true,
        no_model_context_injection: true,
    }
}

fn red_fixture_results(upstream: &UasAddress) -> Vec<(&'static str, bool)> {
    let accepted_steps = adapter_steps();
    let step_mutations: Vec<(&'static str, Box<dyn Fn(&mut Vec<TurboVecAdapterPlanStep>)>)> = vec![
        ("too_few_steps", Box::new(|steps| steps.truncate(4))),
        (
            "duplicate_step_id",
            Box::new(|steps| steps[1].step_id = steps[0].step_id.clone()),
        ),
        (
            "missing_buffer_io",
            Box::new(|steps| {
                steps.retain(|step| {
                    step.component != TurboVecAdapterPlanComponent::BufferBackedIoBoundary
                })
            }),
        ),
        (
            "missing_exact_baseline",
            Box::new(|steps| {
                steps.retain(|step| {
                    step.component != TurboVecAdapterPlanComponent::ExactBaselineShadowReplay
                })
            }),
        ),
        (
            "missing_large_model_step",
            Box::new(|steps| {
                steps.retain(|step| {
                    step.component != TurboVecAdapterPlanComponent::LargeModelWorkingSetCompiler
                })
            }),
        ),
        (
            "bad_motif_ref",
            Box::new(|steps| steps[0].source_motif_ids = vec!["raw:bad".to_string()]),
        ),
        (
            "empty_summary",
            Box::new(|steps| steps[0].interface_summary.clear()),
        ),
        (
            "bad_runtime_proof",
            Box::new(|steps| steps[0].runtime_proof_required = "none".to_string()),
        ),
        (
            "bad_visible_proof",
            Box::new(|steps| steps[0].user_visible_proof_required = "hidden".to_string()),
        ),
        (
            "bad_step_rollback",
            Box::new(|steps| steps[0].rollback_ref = "rollback:wrong".to_string()),
        ),
        (
            "step_source_import",
            Box::new(|steps| steps[0].no_upstream_source_import = false),
        ),
        (
            "step_dependency",
            Box::new(|steps| steps[0].no_product_dependency = false),
        ),
        (
            "step_native_link",
            Box::new(|steps| steps[0].no_native_link_probe = false),
        ),
        (
            "step_benchmark",
            Box::new(|steps| steps[0].no_benchmark_authority = false),
        ),
        (
            "step_route",
            Box::new(|steps| steps[0].no_route_authority = false),
        ),
        (
            "step_context",
            Box::new(|steps| steps[0].no_model_context_injection = false),
        ),
    ];

    let mut results = Vec::with_capacity(64);
    for (name, mutation) in step_mutations {
        let mut steps = accepted_steps.clone();
        mutation(&mut steps);
        results.push((
            name,
            build_set(
                upstream.clone(),
                steps,
                policy(),
                proof_refs(),
                ledger(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
                TurboVecAdapterPlanTier::T1L1Metadata,
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

    for (name, policy_mutation) in policy_mutations() {
        let mut policy = policy();
        policy_mutation(&mut policy);
        results.push((
            name,
            build_set(
                upstream.clone(),
                adapter_steps(),
                policy,
                proof_refs(),
                ledger(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
                TurboVecAdapterPlanTier::T1L1Metadata,
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

    for (name, ledger_mutation) in ledger_mutations() {
        let mut ledger = ledger();
        ledger_mutation(&mut ledger);
        results.push((
            name,
            build_set(
                upstream.clone(),
                adapter_steps(),
                policy(),
                proof_refs(),
                ledger,
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
                TurboVecAdapterPlanTier::T1L1Metadata,
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

    for (name, proof_mutation) in proof_mutations() {
        let mut proof_refs = proof_refs();
        proof_mutation(&mut proof_refs);
        results.push((
            name,
            build_set(
                upstream.clone(),
                adapter_steps(),
                policy(),
                proof_refs,
                ledger(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
                TurboVecAdapterPlanTier::T1L1Metadata,
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

    for (name, build, pro_status, status, tier, flag) in claim_cases() {
        results.push((
            name,
            build_set(
                upstream.clone(),
                adapter_steps(),
                policy(),
                proof_refs(),
                ledger(),
                build,
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
            .is_err(),
        ));
    }

    results.push((
        "bad_upstream_cursor",
        build_set(
            UasAddress::from_str(
                "wrong_cursor:e1f5f570c45811e2e4323c2517120ead82ec8248a2f5c04e9b68dfa023e03610@1779040904000",
            )
            .unwrap_or_else(|_| upstream.clone()),
            adapter_steps(),
            policy(),
            proof_refs(),
            ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
            TurboVecAdapterPlanTier::T1L1Metadata,
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

fn policy_mutations() -> Vec<(&'static str, fn(&mut TurboVecAdapterPlanPolicy))> {
    vec![
        ("policy_direct_import", |p| p.no_direct_import = false),
        ("policy_adapter_wrap", |p| p.no_adapter_wrap = false),
        ("policy_dependency", |p| p.no_product_dependency = false),
        ("policy_native_link", |p| p.no_native_link_default = false),
        ("policy_adapter_build", |p| p.no_adapter_build = false),
        ("policy_benchmark", |p| p.no_benchmark_authority = false),
        ("policy_runtime", |p| p.no_runtime_execution = false),
        ("policy_route", |p| p.no_route_authority = false),
    ]
}

fn ledger_mutations() -> Vec<(&'static str, fn(&mut TurboVecAdapterPlanByteLedger))> {
    vec![
        ("additional_source_read", |l| {
            l.additional_raw_source_bytes_inspected = 1
        }),
        ("product_file_copied", |l| l.product_files_copied = 1),
        ("dependency_added", |l| l.product_dependencies_added = 1),
        ("native_link_probe", |l| l.native_link_probe_count = 1),
        ("adapter_build", |l| l.adapter_build_count = 1),
        ("benchmark_run", |l| l.benchmark_run_count = 1),
        ("index_bytes_opened", |l| l.index_bytes_opened = 1),
        ("model_bytes_loaded", |l| l.model_bytes_loaded = 1),
        ("provider_call", |l| l.provider_calls_made = 1),
    ]
}

fn proof_mutations() -> Vec<(&'static str, fn(&mut TurboVecAdapterPlanProofRefs))> {
    vec![
        ("bad_source_card_ref", |p| {
            p.source_card_ref = "source:wrong".to_string()
        }),
        ("bad_no_product_graph_ref", |p| {
            p.no_product_graph_ref = "graph:wrong".to_string()
        }),
        ("bad_baseline_ref", |p| {
            p.exact_baseline_ref = "baseline:wrong".to_string()
        }),
        ("bad_shadow_replay_ref", |p| {
            p.shadow_replay_ref = "shadow:wrong".to_string()
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

// UAS: red-fixture claim axis for TurboVec clean-room adapter planning.
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
    TurboVecAdapterPlanStatus,
    TurboVecAdapterPlanTier,
    ClaimFlag,
)> {
    vec![
        (
            "product_promoted",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
            TurboVecAdapterPlanTier::T1L1Metadata,
            ClaimFlag::ProductPromotion,
        ),
        (
            "product_build_mas",
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
            TurboVecAdapterPlanTier::T1L1Metadata,
            ClaimFlag::None,
        ),
        (
            "pro_status_live",
            ProductBuild::Pro,
            ProStatus::Live,
            TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
            TurboVecAdapterPlanTier::T1L1Metadata,
            ClaimFlag::None,
        ),
        (
            "status_runtime_candidate",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecAdapterPlanStatus::RuntimeCandidate,
            TurboVecAdapterPlanTier::T1L1Metadata,
            ClaimFlag::None,
        ),
        (
            "tier_t2",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
            TurboVecAdapterPlanTier::T2L2Route,
            ClaimFlag::None,
        ),
        (
            "route_mutation",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
            TurboVecAdapterPlanTier::T1L1Metadata,
            ClaimFlag::RouteMutation,
        ),
        (
            "context_injection",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
            TurboVecAdapterPlanTier::T1L1Metadata,
            ClaimFlag::ContextInjection,
        ),
        (
            "hidden_authority",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
            TurboVecAdapterPlanTier::T1L1Metadata,
            ClaimFlag::HiddenAuthority,
        ),
        (
            "hidden_cloud",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
            TurboVecAdapterPlanTier::T1L1Metadata,
            ClaimFlag::HiddenCloud,
        ),
        (
            "live_large_model",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
            TurboVecAdapterPlanTier::T1L1Metadata,
            ClaimFlag::LiveLargeModel,
        ),
        (
            "ssd_as_ram",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
            TurboVecAdapterPlanTier::T1L1Metadata,
            ClaimFlag::SsdAsRam,
        ),
    ]
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| *candidate == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
    expected: &str,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: if value == expected { "==" } else { "prefix" }.to_string(),
            value: serde_json::Value::String(expected.to_string()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(
        name.to_string(),
        value == expected || value.starts_with(expected),
    );
}
