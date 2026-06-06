//! `falsify_turbovec_real_adapter_owner_approval_probe`
//!
//! Metadata-only witness for `F-TurboVec-RealAdapterOwnerApprovalProbe`.
//! It records a candidate real TurboVec source only as a future quarantine
//! reference. Owner approval, source pinning, fork sweep, rollback, logs,
//! AnswerPacket, and clean-room provenance must exist before any source bytes
//! are fetched, imported, built, or allowed near routing.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, TurboVecIndexOrgan, TurboVecRealAdapterAllowedAction,
    TurboVecRealAdapterOwnerApprovalPolicy, TurboVecRealAdapterOwnerApprovalProbeSet,
    TurboVecRealAdapterOwnerApprovalStatus, TurboVecRealAdapterOwnerApprovalTier,
    TurboVecRealAdapterOwnerByteLedger, TurboVecRealAdapterSourceCard,
    TurboVecRealAdapterSourceKind, UasAddress, TURBOVEC_REAL_ADAPTER_OWNER_APPROVAL_CURSOR,
    TURBOVEC_REAL_ADAPTER_OWNER_APPROVAL_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RealAdapterOwnerApprovalProbe";
const FIXTURE_ID: &str = "turbovec_real_adapter_owner_approval_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_real_adapter_owner_approval_probe.sh";
const RESULT: &str = "artifacts/falsifiers/turbovec_real_adapter_owner_approval_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_quarantine_adapter_microbench_probe/result.json";
const SET_METADATA_BYTES: u64 = 48_000;
const RED_FIXTURE_FLOOR: u64 = 40;
const SOURCE_CARD_ID: &str = "ryancodrai_turbovec_upstream_pending_owner_approval";
const SOURCE_URL: &str = "https://github.com/RyanCodrai/turbovec";
const OWNER_REPO: &str = "RyanCodrai/turbovec";

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
        "{FALSIFIER_ID}: overall_pass={} source_cards={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["source_card_count"].value,
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
    let upstream = upstream_microbench_address()?;
    let cards = accepted_cards();
    let set = build_set(upstream.clone(), cards.clone())?;
    let reversed = build_set(upstream.clone(), cards.iter().cloned().rev().collect())?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&upstream, &cards)?;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_quarantine_microbench_bound",
            set.upstream_microbench_witness_ref
                == "artifact:turbovec_quarantine_adapter_microbench_probe:result"
                && set
                    .upstream_microbench_address
                    .to_string()
                    .starts_with("turbovec_quarantine_adapter_microbench_probe:"),
        ),
        (
            "source_card_present",
            cards
                .iter()
                .any(|card| card.source_card_id == SOURCE_CARD_ID),
        ),
        (
            "primary_source_bound",
            cards.iter().all(|card| {
                card.source_url == SOURCE_URL
                    && card.owner_repo == OWNER_REPO
                    && card.license_id == "MIT"
            }) && red_pass(&red_results, "bad_source_url")
                && red_pass(&red_results, "bad_owner_repo")
                && red_pass(&red_results, "bad_license"),
        ),
        (
            "language_and_api_refs_bound",
            metrics.source_card_count == 1
                && red_pass(&red_results, "missing_rust_language")
                && red_pass(&red_results, "missing_python_language")
                && red_pass(&red_results, "missing_api_ref")
                && red_pass(&red_results, "bad_api_prefix"),
        ),
        (
            "owner_approval_pending_fail_closed",
            metrics.pending_owner_approval_count == metrics.source_card_count
                && metrics.owner_approval_granted_count == 0
                && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "owner_approval_not_required")
                && red_pass(&red_results, "bad_owner_ref"),
        ),
        (
            "source_pin_pending_until_owner_selection",
            metrics.pending_source_pin_count == metrics.source_card_count
                && metrics.source_revision_pinned_count == 0
                && red_pass(&red_results, "source_revision_pinned")
                && red_pass(&red_results, "bad_source_pin_ref"),
        ),
        (
            "quarantine_reference_only",
            metrics.quarantine_reference_count == metrics.source_card_count
                && red_pass(&red_results, "direct_import")
                && red_pass(&red_results, "adapter_wrap")
                && red_pass(&red_results, "product_integration")
                && red_pass(&red_results, "bad_quarantine_path"),
        ),
        (
            "fork_sweep_required_before_source_pin",
            metrics.fork_sweep_required_count == metrics.source_card_count
                && red_pass(&red_results, "fork_sweep_not_required"),
        ),
        (
            "provenance_dependency_and_benchmark_caveats_required",
            red_pass(&red_results, "missing_provenance")
                && red_pass(&red_results, "missing_dependency_manifest")
                && red_pass(&red_results, "missing_benchmark_caveat")
                && red_pass(&red_results, "benchmark_laundered"),
        ),
        (
            "proof_surfaces_required",
            red_pass(&red_results, "missing_rollback")
                && red_pass(&red_results, "missing_run_event_log")
                && red_pass(&red_results, "missing_answer_packet")
                && red_pass(&red_results, "missing_compatibility_fence")
                && metrics.visible_summary_count == metrics.source_card_count
                && red_pass(&red_results, "short_visible_summary"),
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
                && red_pass(&red_results, "fetched_repo_bytes")
                && red_pass(&red_results, "cloned_repo_bytes")
                && red_pass(&red_results, "copied_product_file")
                && red_pass(&red_results, "imported_external_crate")
                && red_pass(&red_results, "built_external_binary")
                && red_pass(&red_results, "opened_product_index")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "provider_call"),
        ),
        (
            "no_route_context_or_hidden_authority",
            metrics.route_mutation_count == 0
                && metrics.model_context_injection_count == 0
                && metrics.hidden_authority_count == 0
                && red_pass(&red_results, "route_mutation_allowed")
                && red_pass(&red_results, "model_context_injected")
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "product_and_large_model_claims_rejected",
            red_pass(&red_results, "product_capability_promoted")
                && red_pass(&red_results, "set_product_promoted")
                && red_pass(&red_results, "product_build_mas")
                && red_pass(&red_results, "pro_status_live")
                && red_pass(&red_results, "promotion_tier_t2")
                && red_pass(&red_results, "live_large_model_claimed")
                && red_pass(&red_results, "ssd_as_ram_claimed"),
        ),
        (
            "reversed_order_address_deterministic",
            set.set_address == reversed.set_address,
        ),
        (
            "layer_separation_required",
            matches!(set.product_build, ProductBuild::Pro)
                && matches!(set.pro_status, ProStatus::ResearchCandidate)
                && matches!(
                    set.promotion_tier,
                    TurboVecRealAdapterOwnerApprovalTier::T1L1Metadata
                ),
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
            "source_card_count",
            metrics.source_card_count,
            1,
            "==",
            "cards",
        ),
        (
            "pending_owner_approval_count",
            metrics.pending_owner_approval_count,
            1,
            "==",
            "cards",
        ),
        (
            "pending_source_pin_count",
            metrics.pending_source_pin_count,
            1,
            "==",
            "cards",
        ),
        (
            "max_planned_quarantine_bytes",
            metrics.max_planned_quarantine_bytes,
            8 * 1024 * 1024,
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

    measurements.insert(
        "real_adapter_owner_approval_address".to_string(),
        Measurement {
            value: serde_json::json!(set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "real_adapter_owner_approval_address".to_string(),
        agent_core::falsifier_artifacts::AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("turbovec_real_adapter_owner_approval_probe:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "real_adapter_owner_approval_address".to_string(),
        set.set_address
            .to_string()
            .starts_with("turbovec_real_adapter_owner_approval_probe:"),
    );
    measurements.insert(
        "next_research_to_build_unit".to_string(),
        Measurement {
            value: serde_json::json!(TURBOVEC_REAL_ADAPTER_OWNER_APPROVAL_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_research_to_build_unit".to_string(),
        agent_core::falsifier_artifacts::AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(TURBOVEC_REAL_ADAPTER_OWNER_APPROVAL_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert("next_research_to_build_unit".to_string(), true);

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
            "kind": "owner_approval_pending_scope",
            "detail": "No repository bytes fetched or cloned, no external crate imported, no product files copied, no adapter built or run, no product index opened, no model/runtime bytes loaded, no provider calls, no route mutation, and no L2/L3/product promotion."
        })],
        notes: "Builds F-TurboVec-RealAdapterOwnerApprovalProbe from the synthetic quarantine microbench. Scope is T1/L1 source/provenance gating only: upstream TurboVec source card, MIT/license/source URL binding, owner approval pending, source pin pending, fork sweep required, quarantine-reference-only action, clean-room provenance, dependency manifest, upstream benchmark caveat, rollback, RunEventLog, AnswerPacket, compatibility fence, zero external/product/model/provider bytes, and no live large-model claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_microbench_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec quarantine microbench has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_REAL_ADAPTER_OWNER_APPROVAL_CURSOR)
    {
        return Err("upstream microbench does not point at real-adapter owner gate".into());
    }
    for axis in [
        "/pass_per_axis/provenance_clean_room_enforced",
        "/pass_per_axis/product_runtime_model_bytes_zero",
        "/pass_per_axis/no_route_or_context_authority",
        "/pass_per_axis/product_promotion_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(format!("upstream microbench axis missing or false: {axis}").into());
        }
    }
    let address = value
        .pointer("/measurements/quarantine_microbench_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("upstream quarantine microbench address missing")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream: UasAddress,
    cards: Vec<TurboVecRealAdapterSourceCard>,
) -> Result<TurboVecRealAdapterOwnerApprovalProbeSet, Box<dyn std::error::Error>> {
    Ok(TurboVecRealAdapterOwnerApprovalProbeSet::from_cards(
        upstream,
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecRealAdapterOwnerApprovalStatus::PendingOwnerApproval,
        TurboVecRealAdapterOwnerApprovalTier::T1L1Metadata,
        vec![
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ],
        TurboVecRealAdapterOwnerApprovalPolicy::fail_closed(),
        SET_METADATA_BYTES,
        false,
    )?)
}

fn accepted_cards() -> Vec<TurboVecRealAdapterSourceCard> {
    vec![TurboVecRealAdapterSourceCard {
        source_card_id: SOURCE_CARD_ID.to_string(),
        source_kind: TurboVecRealAdapterSourceKind::UpstreamGithubRepo,
        source_url: SOURCE_URL.to_string(),
        owner_repo: OWNER_REPO.to_string(),
        license_id: "MIT".to_string(),
        declared_language_refs: vec!["language:rust".to_string(), "language:python".to_string()],
        expected_api_refs: vec![
            "api:turbovec:stable_external_ids".to_string(),
            "api:turbovec:allowlist_search".to_string(),
            "api:turbovec:persistence".to_string(),
            "api:turbovec:python_bindings".to_string(),
        ],
        allowed_action: TurboVecRealAdapterAllowedAction::QuarantineReferenceOnly,
        owner_approval_ref: "owner_approval:pending:turbovec-real-adapter:ryancodrai_turbovec"
            .to_string(),
        source_pin_ref: "source_pin:pending_owner_selection:ryancodrai_turbovec".to_string(),
        quarantine_path_ref:
            "quarantine_path:pending:.research-quarantine/turbovec/ryancodrai_turbovec"
                .to_string(),
        provenance_ref: "provenance:turbovec-real-adapter:ryancodrai_turbovec".to_string(),
        dependency_manifest_ref: "dependency_manifest:quarantine-only:turbovec".to_string(),
        benchmark_caveat_ref: "benchmark_caveat:upstream-not-product-proof:turbovec".to_string(),
        rollback_ref: "rollback:turbovec-real-adapter:ryancodrai_turbovec".to_string(),
        run_event_log_ref: "run_event_log:turbovec-real-adapter:ryancodrai_turbovec".to_string(),
        answer_packet_ref: "answer_packet:turbovec-real-adapter:ryancodrai_turbovec".to_string(),
        compatibility_fence_ref: "compat:turbovec-real-adapter:ryancodrai_turbovec".to_string(),
        visible_summary: "TurboVec upstream is recorded only as a future quarantine reference for compressed retrieval. Owner approval, fork sweep, source pinning, dependency isolation, rollback, RunEventLog, AnswerPacket, and clean-room provenance must pass before any repository bytes are fetched, cloned, imported, built, or cited by routing.".to_string(),
        byte_ledger: TurboVecRealAdapterOwnerByteLedger::pending(42_000, 8 * 1024 * 1024),
        fork_sweep_required_before_source_pin: true,
        owner_approval_required: true,
        owner_approval_granted: false,
        source_revision_pinned: false,
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
    }]
}

fn red_fixture_results(
    upstream: &UasAddress,
    cards: &[TurboVecRealAdapterSourceCard],
) -> Result<Vec<(String, bool)>, Box<dyn std::error::Error>> {
    let mut results = Vec::new();
    let mut push = |name: &str, mutate: fn(&mut Vec<TurboVecRealAdapterSourceCard>)| {
        let mut red = cards.to_vec();
        mutate(&mut red);
        let passed = build_set(upstream.clone(), red).is_err();
        results.push((name.to_string(), passed));
    };

    push("bad_source_url", |cards| {
        cards[0].source_url = "http://example.com".to_string()
    });
    push("bad_owner_repo", |cards| {
        cards[0].owner_repo = "other/repo".to_string()
    });
    push("bad_license", |cards| {
        cards[0].license_id = "NOASSERTION".to_string()
    });
    push("missing_rust_language", |cards| {
        cards[0]
            .declared_language_refs
            .retain(|item| item != "language:rust")
    });
    push("missing_python_language", |cards| {
        cards[0]
            .declared_language_refs
            .retain(|item| item != "language:python")
    });
    push("missing_api_ref", |cards| {
        cards[0].expected_api_refs.clear()
    });
    push("bad_api_prefix", |cards| {
        cards[0].expected_api_refs[0] = "api:wrong".to_string()
    });
    push("owner_approval_granted", |cards| {
        cards[0].owner_approval_granted = true
    });
    push("owner_approval_not_required", |cards| {
        cards[0].owner_approval_required = false
    });
    push("bad_owner_ref", |cards| {
        cards[0].owner_approval_ref = "owner_approval:granted:turbovec".to_string()
    });
    push("source_revision_pinned", |cards| {
        cards[0].source_revision_pinned = true
    });
    push("bad_source_pin_ref", |cards| {
        cards[0].source_pin_ref = "source_pin:sha:deadbeef".to_string()
    });
    push("direct_import", |cards| {
        cards[0].allowed_action = TurboVecRealAdapterAllowedAction::DirectImport
    });
    push("adapter_wrap", |cards| {
        cards[0].allowed_action = TurboVecRealAdapterAllowedAction::AdapterWrap
    });
    push("product_integration", |cards| {
        cards[0].allowed_action = TurboVecRealAdapterAllowedAction::ProductIntegration
    });
    push("bad_quarantine_path", |cards| {
        cards[0].quarantine_path_ref = "product_path:agent_core".to_string()
    });
    push("fork_sweep_not_required", |cards| {
        cards[0].fork_sweep_required_before_source_pin = false
    });
    push("missing_provenance", |cards| {
        cards[0].provenance_ref.clear()
    });
    push("missing_dependency_manifest", |cards| {
        cards[0].dependency_manifest_ref.clear()
    });
    push("missing_benchmark_caveat", |cards| {
        cards[0].benchmark_caveat_ref.clear()
    });
    push("benchmark_laundered", |cards| {
        cards[0].upstream_benchmark_claimed_as_product_proof = true
    });
    push("missing_rollback", |cards| cards[0].rollback_ref.clear());
    push("missing_run_event_log", |cards| {
        cards[0].run_event_log_ref.clear()
    });
    push("missing_answer_packet", |cards| {
        cards[0].answer_packet_ref.clear()
    });
    push("missing_compatibility_fence", |cards| {
        cards[0].compatibility_fence_ref.clear()
    });
    push("short_visible_summary", |cards| {
        cards[0].visible_summary = "too short".to_string()
    });
    push("fetched_repo_bytes", |cards| {
        cards[0].byte_ledger.fetched_repo_bytes = 1
    });
    push("cloned_repo_bytes", |cards| {
        cards[0].byte_ledger.cloned_repo_bytes = 1
    });
    push("copied_product_file", |cards| {
        cards[0].byte_ledger.copied_product_file_count = 1
    });
    push("imported_external_crate", |cards| {
        cards[0].byte_ledger.imported_external_crate_count = 1
    });
    push("built_external_binary", |cards| {
        cards[0].byte_ledger.built_external_binary_count = 1
    });
    push("opened_product_index", |cards| {
        cards[0].byte_ledger.opened_product_index_bytes = 1
    });
    push("model_bytes_loaded", |cards| {
        cards[0].byte_ledger.model_bytes_loaded = 1
    });
    push("provider_call", |cards| {
        cards[0].byte_ledger.provider_calls_made = 1
    });
    push("route_mutation_allowed", |cards| {
        cards[0].route_mutation_allowed = true
    });
    push("model_context_injected", |cards| {
        cards[0].model_context_injected = true
    });
    push("hidden_route_authority", |cards| {
        cards[0].hidden_route_authority = true
    });
    push("hidden_cloud_fallback", |cards| {
        cards[0].hidden_cloud_fallback_allowed = true
    });
    push("product_capability_promoted", |cards| {
        cards[0].product_capability_promoted = true
    });
    push("live_large_model_claimed", |cards| {
        cards[0].live_large_model_claimed = true
    });
    push("ssd_as_ram_claimed", |cards| {
        cards[0].ssd_as_ram_claimed = true
    });
    let product_build_mas = TurboVecRealAdapterOwnerApprovalProbeSet::from_cards(
        upstream.clone(),
        cards.to_vec(),
        ProductBuild::Mas,
        ProStatus::ResearchCandidate,
        TurboVecRealAdapterOwnerApprovalStatus::PendingOwnerApproval,
        TurboVecRealAdapterOwnerApprovalTier::T1L1Metadata,
        organs(),
        TurboVecRealAdapterOwnerApprovalPolicy::fail_closed(),
        SET_METADATA_BYTES,
        false,
    )
    .is_err();
    results.push(("product_build_mas".to_string(), product_build_mas));
    let pro_status_live = TurboVecRealAdapterOwnerApprovalProbeSet::from_cards(
        upstream.clone(),
        cards.to_vec(),
        ProductBuild::Pro,
        ProStatus::Live,
        TurboVecRealAdapterOwnerApprovalStatus::PendingOwnerApproval,
        TurboVecRealAdapterOwnerApprovalTier::T1L1Metadata,
        organs(),
        TurboVecRealAdapterOwnerApprovalPolicy::fail_closed(),
        SET_METADATA_BYTES,
        false,
    )
    .is_err();
    results.push(("pro_status_live".to_string(), pro_status_live));
    let promotion_tier_t2 = TurboVecRealAdapterOwnerApprovalProbeSet::from_cards(
        upstream.clone(),
        cards.to_vec(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecRealAdapterOwnerApprovalStatus::PendingOwnerApproval,
        TurboVecRealAdapterOwnerApprovalTier::T2L2Route,
        organs(),
        TurboVecRealAdapterOwnerApprovalPolicy::fail_closed(),
        SET_METADATA_BYTES,
        false,
    )
    .is_err();
    results.push(("promotion_tier_t2".to_string(), promotion_tier_t2));
    let set_product_promoted = TurboVecRealAdapterOwnerApprovalProbeSet::from_cards(
        upstream.clone(),
        cards.to_vec(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecRealAdapterOwnerApprovalStatus::PendingOwnerApproval,
        TurboVecRealAdapterOwnerApprovalTier::T1L1Metadata,
        organs(),
        TurboVecRealAdapterOwnerApprovalPolicy::fail_closed(),
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
