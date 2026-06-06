//! `falsify_proprietary_compression_provenance_gate`
//!
//! Metadata-only witness for `F-ProprietaryCompression-ProvenanceGate`. It
//! proves TurboVec/QAT/fork/runtime research can be mined into source-carded
//! provenance overlays without copying product files, loading model/runtime
//! bytes, creating hidden route authority, or promoting product capability.

use std::collections::{BTreeMap, HashSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ModelInventoryByteScope, ModelInventoryCandidateCard, ModelInventoryCandidateSet,
    ModelInventoryClaimLimit, ModelInventoryEvidenceKind, ModelInventoryHashClaim,
    ModelInventoryMetadataStatus, ModelInventoryProofRefs, PrivacyClass, ProStatus, ProductBuild,
    ProprietaryCompressionAllowedAction, ProprietaryCompressionBehaviorKind,
    ProprietaryCompressionByteScope, ProprietaryCompressionExtractedBehavior,
    ProprietaryCompressionImportMode, ProprietaryCompressionLicenseClass,
    ProprietaryCompressionProofRefs, ProprietaryCompressionProvenanceGate,
    ProprietaryCompressionSourceKind, ProprietaryCompressionSourceOverlay, SourceCard,
    SourceNoPoisonStatus, SourceSignalGraph, SourceSignalType,
};

const FALSIFIER_ID: &str = "F-ProprietaryCompression-ProvenanceGate";
const FIXTURE_ID: &str = "proprietary_compression_provenance_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_proprietary_compression_provenance_gate.sh";
const RESULT: &str = "artifacts/falsifiers/proprietary_compression_provenance_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_032_000_000;
const GATE_METADATA_BYTES: u64 = 72_000;

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
        "{FALSIFIER_ID}: overall_pass={} overlay_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["accepted_fixture_count"].value,
        artifact.measurements["red_fixture_rejection_count"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let graph = source_graph()?;
    let inventory = model_inventory(&graph)?;
    let overlays = accepted_overlays(&graph);
    let gate = build_gate(&graph, &inventory, overlays.clone())?;
    let reversed = build_gate(&graph, &inventory, overlays.iter().cloned().rev().collect())?;
    let metrics = gate.metrics();
    let red_results = red_fixture_results(&graph, &inventory, &overlays);

    let accepted_fixture_count = overlays.len() as u64;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "source_signal_graph_intake_called_first",
            !graph.source_cards.is_empty(),
        ),
        (
            "model_inventory_candidate_set_bound",
            metrics.model_inventory_binding_count >= 3,
        ),
        ("source_kind_coverage", metrics.source_kind_count >= 8),
        ("license_class_coverage", metrics.license_class_count >= 7),
        ("import_mode_coverage", metrics.import_mode_count >= 5),
        ("allowed_action_coverage", metrics.allowed_action_count >= 6),
        ("behavior_kind_coverage", metrics.behavior_kind_count >= 10),
        (
            "quarantine_required_for_unclear_or_no_license",
            red_pass(&red_results, "missing_quarantine_ref"),
        ),
        (
            "direct_import_permissive_only",
            red_pass(&red_results, "no_license_direct_import")
                && red_pass(&red_results, "unclear_license_direct_import")
                && red_pass(&red_results, "copyleft_direct_import"),
        ),
        (
            "adapter_wrap_safe_license_only",
            red_pass(&red_results, "unsafe_adapter_license"),
        ),
        (
            "direct_import_attribution_required",
            red_pass(&red_results, "direct_import_missing_attribution"),
        ),
        (
            "direct_import_test_plan_required",
            red_pass(&red_results, "direct_import_missing_test_plan"),
        ),
        (
            "adapter_test_plan_required",
            red_pass(&red_results, "adapter_missing_test_plan"),
        ),
        (
            "clean_room_note_required",
            red_pass(&red_results, "missing_clean_room_note"),
        ),
        (
            "local_test_plan_required_for_benchmark_claim",
            red_pass(&red_results, "benchmark_without_local_test_plan"),
        ),
        (
            "dependency_closure_declared",
            metrics.transitive_unknown_dependency_count == 0,
        ),
        (
            "transitive_unknown_deps_rejected",
            red_pass(&red_results, "unknown_transitive_dependency_direct_import"),
        ),
        (
            "no_copied_files_in_metadata_gate",
            metrics.copied_product_file_count == 0 && red_pass(&red_results, "product_file_copied"),
        ),
        (
            "verbatim_code_rejected",
            red_pass(&red_results, "verbatim_code_used"),
        ),
        (
            "source_digest_bound",
            red_pass(&red_results, "source_digest_mismatch"),
        ),
        (
            "duplicate_overlay_rejected",
            red_pass(&red_results, "duplicate_overlay_id"),
        ),
        (
            "duplicate_source_rejected",
            red_pass(&red_results, "duplicate_source_id"),
        ),
        (
            "orphan_source_rejected",
            red_pass(&red_results, "orphan_source_id"),
        ),
        (
            "blocked_source_rejected",
            red_pass(&red_results, "blocked_source_id"),
        ),
        (
            "duplicate_locator_rejected",
            red_pass(&red_results, "duplicate_locator"),
        ),
        (
            "model_inventory_candidate_ref_checked",
            red_pass(&red_results, "unknown_model_inventory_candidate")
                && red_pass(&red_results, "model_inventory_source_mismatch"),
        ),
        (
            "hidden_route_authority_rejected",
            red_pass(&red_results, "hidden_route_authority"),
        ),
        (
            "hidden_cloud_rejected",
            red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "live_dense_70b_claim_rejected",
            red_pass(&red_results, "dense_70b_live_claim"),
        ),
        (
            "ssd_as_ram_claim_rejected",
            red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "product_promotion_rejected",
            red_pass(&red_results, "product_green_from_research"),
        ),
        (
            "mas_live_rejected",
            red_pass(&red_results, "mas_live_from_research"),
        ),
        ("zero_model_bytes_loaded", metrics.model_bytes_loaded == 0),
        ("zero_index_bytes_loaded", metrics.index_bytes_loaded == 0),
        (
            "zero_runtime_bytes_loaded",
            metrics.runtime_bytes_loaded == 0,
        ),
        ("zero_provider_calls", metrics.provider_calls_made == 0),
        (
            "rollback_run_event_answer_packet_refs_present",
            overlays.iter().all(|overlay| {
                overlay.proof_refs.rollback_ref.starts_with("rollback:")
                    && overlay
                        .proof_refs
                        .run_event_log_ref
                        .starts_with("run_event_log:")
                    && overlay
                        .proof_refs
                        .answer_packet_ref
                        .starts_with("answer_packet:")
            }),
        ),
        (
            "proof_ref_prefixes_rejected",
            red_pass(&red_results, "missing_rollback_ref")
                && red_pass(&red_results, "bad_answer_packet_prefix"),
        ),
        (
            "metadata_budget_enforced",
            red_pass(&red_results, "metadata_budget_exceeded"),
        ),
        (
            "quarantine_budget_enforced",
            red_pass(&red_results, "quarantine_budget_exceeded"),
        ),
        (
            "layer_separation_required",
            red_pass(&red_results, "missing_layer_separation"),
        ),
        (
            "gate_address_deterministic",
            gate.gate_address == reversed.gate_address,
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

    for (name, pass) in &red_results {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            *pass,
        );
    }

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "accepted_fixture_count",
        accepted_fixture_count,
        9,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        34,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        red_results.len() as u64,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "behavior_count",
        metrics.behavior_count,
        12,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_inventory_binding_count",
        metrics.model_inventory_binding_count,
        3,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes_read",
        metrics.metadata_bytes_read + GATE_METADATA_BYTES,
        768 * 1024,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "quarantine_source_bytes_inspected",
        metrics.quarantine_source_bytes_inspected,
        2 * 1024 * 1024,
        "<=",
    );
    measurements.insert(
        "provenance_gate_address".to_string(),
        Measurement {
            value: serde_json::json!(gate.address()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "provenance_gate_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("proprietary_compression_provenance_gate:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "provenance_gate_address".to_string(),
        gate.address()
            .starts_with("proprietary_compression_provenance_gate:")
            && gate.address().contains('@'),
    );

    let artifact = ArtifactBuilder {
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
            "kind": "scope_guard",
            "detail": "metadata-only provenance gate; no copied product files, no model/runtime/index bytes, no provider calls, no hidden route authority, and no L2/L3 promotion"
        })],
        notes: "Builds F-ProprietaryCompression-ProvenanceGate from source-carded TurboVec/QAT/runtime/fork/local-canon fixtures. This converts deep research into a buildable L1 gate while keeping all risky imports in quarantine, adapter, clean-room, or research-only status until later byte/runtime/WRV witnesses pass.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn red_fixture_results(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    overlays: &[ProprietaryCompressionSourceOverlay],
) -> Vec<(&'static str, bool)> {
    vec![
        (
            "empty_overlay_id",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.overlay_id.clear()
            }),
        ),
        (
            "duplicate_overlay_id",
            reject_overlays(graph, inventory, overlays, |overlays| {
                overlays[1].overlay_id = overlays[0].overlay_id.clone()
            }),
        ),
        (
            "duplicate_source_id",
            reject_overlays(graph, inventory, overlays, |overlays| {
                overlays[1].source_id = overlays[0].source_id.clone()
            }),
        ),
        (
            "duplicate_locator",
            reject_overlays(graph, inventory, overlays, |overlays| {
                overlays[1].source_locator = overlays[0].source_locator.clone()
            }),
        ),
        (
            "orphan_source_id",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.source_id = "source:missing".to_string()
            }),
        ),
        (
            "blocked_source_id",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.source_id = "source:blocked:poison".to_string()
            }),
        ),
        (
            "source_digest_mismatch",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.source_digest = digest("wrong-digest")
            }),
        ),
        (
            "missing_behavior",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.extracted_behaviors.clear()
            }),
        ),
        (
            "duplicate_behavior_id",
            reject_overlay(graph, inventory, overlays, |overlay| {
                let duplicate = overlay.extracted_behaviors[0].clone();
                overlay.extracted_behaviors.push(duplicate);
            }),
        ),
        (
            "verbatim_code_used",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.extracted_behaviors[0].uses_verbatim_code = true
            }),
        ),
        (
            "no_license_direct_import",
            reject_named_overlay(
                graph,
                inventory,
                overlays,
                "negative_fixture_no_license_fork",
                |overlay| {
                    overlay.import_mode = ProprietaryCompressionImportMode::DirectImport;
                    overlay.allowed_action =
                        ProprietaryCompressionAllowedAction::VendorOrAdaptWithAttribution;
                    overlay.attribution_ref = Some("attribution:bad".to_string());
                    overlay.local_test_plan_ref = Some("test-plan:bad".to_string());
                },
            ),
        ),
        (
            "unclear_license_direct_import",
            reject_named_overlay(
                graph,
                inventory,
                overlays,
                "quarantine_turbovec_repo",
                |overlay| {
                    overlay.import_mode = ProprietaryCompressionImportMode::DirectImport;
                    overlay.allowed_action =
                        ProprietaryCompressionAllowedAction::VendorOrAdaptWithAttribution;
                    overlay.attribution_ref = Some("attribution:bad".to_string());
                },
            ),
        ),
        (
            "copyleft_direct_import",
            reject_named_overlay(
                graph,
                inventory,
                overlays,
                "quarantine_copyleft_kv_quant",
                |overlay| {
                    overlay.import_mode = ProprietaryCompressionImportMode::DirectImport;
                    overlay.allowed_action =
                        ProprietaryCompressionAllowedAction::VendorOrAdaptWithAttribution;
                    overlay.attribution_ref = Some("attribution:bad".to_string());
                    overlay.local_test_plan_ref = Some("test-plan:bad".to_string());
                },
            ),
        ),
        (
            "unsafe_adapter_license",
            reject_named_overlay(
                graph,
                inventory,
                overlays,
                "negative_fixture_no_license_fork",
                |overlay| {
                    overlay.import_mode = ProprietaryCompressionImportMode::AdapterWrap;
                    overlay.allowed_action = ProprietaryCompressionAllowedAction::AdapterOnly;
                    overlay.local_test_plan_ref = Some("test-plan:bad".to_string());
                },
            ),
        ),
        (
            "direct_import_missing_attribution",
            reject_named_overlay(
                graph,
                inventory,
                overlays,
                "direct_permissive_vector_cache",
                |overlay| overlay.attribution_ref = None,
            ),
        ),
        (
            "direct_import_missing_test_plan",
            reject_named_overlay(
                graph,
                inventory,
                overlays,
                "direct_permissive_vector_cache",
                |overlay| overlay.local_test_plan_ref = None,
            ),
        ),
        (
            "adapter_missing_test_plan",
            reject_named_overlay(
                graph,
                inventory,
                overlays,
                "adapter_litert_model_license",
                |overlay| overlay.local_test_plan_ref = None,
            ),
        ),
        (
            "missing_quarantine_ref",
            reject_named_overlay(
                graph,
                inventory,
                overlays,
                "quarantine_turbovec_repo",
                |overlay| overlay.quarantine_ref = None,
            ),
        ),
        (
            "missing_clean_room_note",
            reject_named_overlay(
                graph,
                inventory,
                overlays,
                "clean_room_turboquant_math",
                |overlay| overlay.clean_room_note_ref = None,
            ),
        ),
        (
            "benchmark_without_local_test_plan",
            reject_named_overlay(
                graph,
                inventory,
                overlays,
                "benchmark_report_turboquant_repro",
                |overlay| {
                    overlay.benchmark_claim_count = 1;
                    overlay.local_test_plan_ref = None;
                },
            ),
        ),
        (
            "unknown_transitive_dependency_direct_import",
            reject_named_overlay(
                graph,
                inventory,
                overlays,
                "direct_permissive_vector_cache",
                |overlay| overlay.transitive_unknown_dependency_count = 1,
            ),
        ),
        (
            "product_file_copied",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.byte_scope.copied_product_file_count = 1
            }),
        ),
        (
            "nonzero_model_bytes_loaded",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.byte_scope.model_bytes_loaded = 1
            }),
        ),
        (
            "nonzero_index_bytes_loaded",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.byte_scope.index_bytes_loaded = 1
            }),
        ),
        (
            "nonzero_runtime_bytes_loaded",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.byte_scope.runtime_bytes_loaded = 1
            }),
        ),
        (
            "provider_call_made",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.byte_scope.provider_calls_made = 1
            }),
        ),
        (
            "hidden_route_authority",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.source_locator.push_str(":hidden-route-authority")
            }),
        ),
        (
            "hidden_cloud_fallback",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.source_locator.push_str(":hidden-cloud")
            }),
        ),
        (
            "dense_70b_live_claim",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.source_locator.push_str(":live-dense-70b")
            }),
        ),
        (
            "ssd_as_ram_claim",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.source_locator.push_str(":ssd-as-ram")
            }),
        ),
        (
            "product_green_from_research",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.pro_status = ProStatus::Live
            }),
        ),
        (
            "mas_live_from_research",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.product_build = ProductBuild::Mas
            }),
        ),
        (
            "missing_rollback_ref",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.proof_refs.rollback_ref.clear()
            }),
        ),
        (
            "bad_answer_packet_prefix",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.proof_refs.answer_packet_ref = "packet:bad".to_string()
            }),
        ),
        (
            "unknown_model_inventory_candidate",
            reject_named_overlay(
                graph,
                inventory,
                overlays,
                "research_model_card_gemma4_qat",
                |overlay| {
                    overlay.model_inventory_candidate_ref = Some("missing-candidate".to_string())
                },
            ),
        ),
        (
            "model_inventory_source_mismatch",
            reject_named_overlay(
                graph,
                inventory,
                overlays,
                "research_model_card_gemma4_qat",
                |overlay| {
                    overlay.model_inventory_candidate_ref =
                        Some("runtime_candidate_litert".to_string())
                },
            ),
        ),
        (
            "metadata_budget_exceeded",
            gate_with_metadata_bytes_is_err(graph, inventory, overlays, 800 * 1024),
        ),
        (
            "quarantine_budget_exceeded",
            reject_overlay(graph, inventory, overlays, |overlay| {
                overlay.byte_scope.quarantine_source_bytes_inspected = 3 * 1024 * 1024
            }),
        ),
        (
            "missing_layer_separation",
            gate_with_layer_flags_is_err(graph, inventory, overlays, false),
        ),
    ]
}

fn source_graph() -> Result<SourceSignalGraph, Box<dyn std::error::Error>> {
    SourceSignalGraph::intake(
        [
            "source:repo:permissive-vector-cache",
            "source:package:litert-lm-swift",
            "source:repo:turbovec",
            "source:paper:turboquant",
            "source:blog:gemma4-qat",
            "source:fork:no-license-poc",
            "source:fork:copyleft-kv-quant",
            "source:modelcard:gemma4-qat",
            "source:benchmark:turboquant-repro",
            "source:local:canon-runtime-notes",
        ]
        .into_iter()
        .map(|source_id| source_card(source_id, SourceNoPoisonStatus::Clear))
        .chain(std::iter::once(source_card(
            "source:blocked:poison",
            SourceNoPoisonStatus::Blocked,
        )))
        .collect::<Result<Vec<_>, _>>()?,
        Vec::new(),
        CREATED_AT_MS,
    )
    .map_err(Into::into)
}

fn source_card(
    source_id: &str,
    no_poison_status: SourceNoPoisonStatus,
) -> Result<SourceCard, Box<dyn std::error::Error>> {
    Ok(SourceCard::new(
        source_id,
        SourceSignalType::Doc,
        format!("fixture://{source_id}"),
        digest(source_id),
        1,
        "fixture-only compression provenance source; no product import",
        PrivacyClass::PublicResearch,
        no_poison_status,
        vec!["proprietary_compression".to_string()],
    )?)
}

fn model_inventory(
    graph: &SourceSignalGraph,
) -> Result<ModelInventoryCandidateSet, Box<dyn std::error::Error>> {
    let cards = vec![
        inventory_card(
            graph,
            "runtime_candidate_litert",
            "source:package:litert-lm-swift",
            "LiteRT-LM Swift route candidate",
        ),
        inventory_card(
            graph,
            "model_candidate_gemma4_qat",
            "source:modelcard:gemma4-qat",
            "Gemma 4 QAT model-card candidate",
        ),
        inventory_card(
            graph,
            "benchmark_candidate_turboquant_repro",
            "source:benchmark:turboquant-repro",
            "TurboQuant reproduction benchmark card",
        ),
    ];
    Ok(ModelInventoryCandidateSet::from_source_graph(
        graph,
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        32_000,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?)
}

fn inventory_card(
    graph: &SourceSignalGraph,
    candidate_id: &str,
    source_id: &str,
    model_or_package_id: &str,
) -> ModelInventoryCandidateCard {
    ModelInventoryCandidateCard {
        candidate_id: candidate_id.to_string(),
        source_id: source_id.to_string(),
        source_digest: digest_for(graph, source_id),
        model_or_package_id: model_or_package_id.to_string(),
        evidence_kind: ModelInventoryEvidenceKind::PackageManifest,
        metadata_status: ModelInventoryMetadataStatus::DependencyProvenanceOnly,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        claim_limit: ModelInventoryClaimLimit::DependencyProvenanceOnly,
        evidence_locator: format!("fixture://inventory/{candidate_id}"),
        revision_ref: None,
        hash_claim: ModelInventoryHashClaim::None,
        loader_caveat_ref: None,
        route_hint_ref: None,
        sidecar_policy: None,
        byte_scope: ModelInventoryByteScope::metadata_only(512, 0),
        proof_refs: ModelInventoryProofRefs {
            falsifier_ref: format!("falsifier:model-inventory:{candidate_id}"),
            rollback_ref: format!("rollback:model-inventory:{candidate_id}"),
            run_event_log_ref: format!("run_event_log:model-inventory:{candidate_id}"),
            answer_packet_ref: format!("answer_packet:model-inventory:{candidate_id}"),
            compatibility_fence_ref: format!("compat:model-inventory:{candidate_id}"),
        },
        source_observed_at_utc: Some("2026-06-06T00:00:00Z".to_string()),
    }
}

fn accepted_overlays(graph: &SourceSignalGraph) -> Vec<ProprietaryCompressionSourceOverlay> {
    vec![
        overlay(
            graph,
            OverlaySpec {
                overlay_id: "direct_permissive_vector_cache",
                source_id: "source:repo:permissive-vector-cache",
                source_kind: ProprietaryCompressionSourceKind::Repo,
                license_class: ProprietaryCompressionLicenseClass::Permissive,
                import_mode: ProprietaryCompressionImportMode::DirectImport,
                allowed_action: ProprietaryCompressionAllowedAction::VendorOrAdaptWithAttribution,
                behavior_kinds: &[
                    ProprietaryCompressionBehaviorKind::ApiShape,
                    ProprietaryCompressionBehaviorKind::VectorIndexing,
                ],
                local_test_plan_ref: Some("test-plan:vector-cache-direct"),
                quarantine_ref: None,
                clean_room_note_ref: None,
                attribution_ref: Some("attribution:permissive-vector-cache"),
                model_inventory_candidate_ref: None,
                benchmark_claim_count: 1,
            },
        ),
        overlay(
            graph,
            OverlaySpec {
                overlay_id: "adapter_litert_model_license",
                source_id: "source:package:litert-lm-swift",
                source_kind: ProprietaryCompressionSourceKind::RuntimePackage,
                license_class: ProprietaryCompressionLicenseClass::ModelLicense,
                import_mode: ProprietaryCompressionImportMode::AdapterWrap,
                allowed_action: ProprietaryCompressionAllowedAction::AdapterOnly,
                behavior_kinds: &[
                    ProprietaryCompressionBehaviorKind::RuntimeLane,
                    ProprietaryCompressionBehaviorKind::ParserBehavior,
                ],
                local_test_plan_ref: Some("test-plan:litert-adapter"),
                quarantine_ref: None,
                clean_room_note_ref: None,
                attribution_ref: None,
                model_inventory_candidate_ref: Some("runtime_candidate_litert"),
                benchmark_claim_count: 0,
            },
        ),
        overlay(
            graph,
            OverlaySpec {
                overlay_id: "quarantine_turbovec_repo",
                source_id: "source:repo:turbovec",
                source_kind: ProprietaryCompressionSourceKind::Repo,
                license_class: ProprietaryCompressionLicenseClass::Unclear,
                import_mode: ProprietaryCompressionImportMode::QuarantineReference,
                allowed_action: ProprietaryCompressionAllowedAction::QuarantineInspectBenchmark,
                behavior_kinds: &[
                    ProprietaryCompressionBehaviorKind::CacheLogic,
                    ProprietaryCompressionBehaviorKind::MemoryAssumption,
                ],
                local_test_plan_ref: Some("test-plan:turbovec-quarantine"),
                quarantine_ref: Some("quarantine:turbovec"),
                clean_room_note_ref: None,
                attribution_ref: None,
                model_inventory_candidate_ref: None,
                benchmark_claim_count: 1,
            },
        ),
        overlay(
            graph,
            OverlaySpec {
                overlay_id: "clean_room_turboquant_math",
                source_id: "source:paper:turboquant",
                source_kind: ProprietaryCompressionSourceKind::Paper,
                license_class: ProprietaryCompressionLicenseClass::ResearchPaper,
                import_mode: ProprietaryCompressionImportMode::CleanRoomRewrite,
                allowed_action: ProprietaryCompressionAllowedAction::CleanRoomImplement,
                behavior_kinds: &[
                    ProprietaryCompressionBehaviorKind::QuantizationMath,
                    ProprietaryCompressionBehaviorKind::TestFixture,
                ],
                local_test_plan_ref: Some("test-plan:turboquant-math"),
                quarantine_ref: None,
                clean_room_note_ref: Some("clean-room:turboquant-math"),
                attribution_ref: None,
                model_inventory_candidate_ref: None,
                benchmark_claim_count: 1,
            },
        ),
        overlay(
            graph,
            OverlaySpec {
                overlay_id: "research_only_gemma4_qat_blog",
                source_id: "source:blog:gemma4-qat",
                source_kind: ProprietaryCompressionSourceKind::Blog,
                license_class: ProprietaryCompressionLicenseClass::ResearchPaper,
                import_mode: ProprietaryCompressionImportMode::ResearchOnly,
                allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
                behavior_kinds: &[ProprietaryCompressionBehaviorKind::FailureCase],
                local_test_plan_ref: None,
                quarantine_ref: None,
                clean_room_note_ref: None,
                attribution_ref: None,
                model_inventory_candidate_ref: None,
                benchmark_claim_count: 0,
            },
        ),
        overlay(
            graph,
            OverlaySpec {
                overlay_id: "negative_fixture_no_license_fork",
                source_id: "source:fork:no-license-poc",
                source_kind: ProprietaryCompressionSourceKind::Fork,
                license_class: ProprietaryCompressionLicenseClass::NoLicense,
                import_mode: ProprietaryCompressionImportMode::ResearchOnly,
                allowed_action: ProprietaryCompressionAllowedAction::NegativeFixtureOnly,
                behavior_kinds: &[ProprietaryCompressionBehaviorKind::FailureCase],
                local_test_plan_ref: None,
                quarantine_ref: Some("quarantine:no-license-fork"),
                clean_room_note_ref: None,
                attribution_ref: None,
                model_inventory_candidate_ref: None,
                benchmark_claim_count: 0,
            },
        ),
        overlay(
            graph,
            OverlaySpec {
                overlay_id: "quarantine_copyleft_kv_quant",
                source_id: "source:fork:copyleft-kv-quant",
                source_kind: ProprietaryCompressionSourceKind::Fork,
                license_class: ProprietaryCompressionLicenseClass::Copyleft,
                import_mode: ProprietaryCompressionImportMode::QuarantineReference,
                allowed_action: ProprietaryCompressionAllowedAction::QuarantineInspectBenchmark,
                behavior_kinds: &[ProprietaryCompressionBehaviorKind::BenchmarkHarness],
                local_test_plan_ref: Some("test-plan:copyleft-quarantine"),
                quarantine_ref: Some("quarantine:copyleft-kv-quant"),
                clean_room_note_ref: None,
                attribution_ref: None,
                model_inventory_candidate_ref: None,
                benchmark_claim_count: 1,
            },
        ),
        overlay(
            graph,
            OverlaySpec {
                overlay_id: "research_model_card_gemma4_qat",
                source_id: "source:modelcard:gemma4-qat",
                source_kind: ProprietaryCompressionSourceKind::ModelCard,
                license_class: ProprietaryCompressionLicenseClass::ModelLicense,
                import_mode: ProprietaryCompressionImportMode::ResearchOnly,
                allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
                behavior_kinds: &[ProprietaryCompressionBehaviorKind::MemoryAssumption],
                local_test_plan_ref: None,
                quarantine_ref: None,
                clean_room_note_ref: None,
                attribution_ref: None,
                model_inventory_candidate_ref: Some("model_candidate_gemma4_qat"),
                benchmark_claim_count: 0,
            },
        ),
        overlay(
            graph,
            OverlaySpec {
                overlay_id: "benchmark_report_turboquant_repro",
                source_id: "source:benchmark:turboquant-repro",
                source_kind: ProprietaryCompressionSourceKind::BenchmarkReport,
                license_class: ProprietaryCompressionLicenseClass::InternalCanon,
                import_mode: ProprietaryCompressionImportMode::ResearchOnly,
                allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
                behavior_kinds: &[ProprietaryCompressionBehaviorKind::BenchmarkHarness],
                local_test_plan_ref: Some("test-plan:turboquant-repro"),
                quarantine_ref: None,
                clean_room_note_ref: None,
                attribution_ref: None,
                model_inventory_candidate_ref: Some("benchmark_candidate_turboquant_repro"),
                benchmark_claim_count: 1,
            },
        ),
        overlay(
            graph,
            OverlaySpec {
                overlay_id: "local_canon_runtime_notes",
                source_id: "source:local:canon-runtime-notes",
                source_kind: ProprietaryCompressionSourceKind::LocalCanon,
                license_class: ProprietaryCompressionLicenseClass::InternalCanon,
                import_mode: ProprietaryCompressionImportMode::ResearchOnly,
                allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
                behavior_kinds: &[ProprietaryCompressionBehaviorKind::MemoryAssumption],
                local_test_plan_ref: None,
                quarantine_ref: None,
                clean_room_note_ref: None,
                attribution_ref: None,
                model_inventory_candidate_ref: None,
                benchmark_claim_count: 0,
            },
        ),
    ]
}

// UAS: uas:proprietary-compression:falsifier-overlay-spec
// Plane: Verification
// Residency: metadata-only fixture builder; no source/runtime/model bytes.
struct OverlaySpec<'a> {
    overlay_id: &'a str,
    source_id: &'a str,
    source_kind: ProprietaryCompressionSourceKind,
    license_class: ProprietaryCompressionLicenseClass,
    import_mode: ProprietaryCompressionImportMode,
    allowed_action: ProprietaryCompressionAllowedAction,
    behavior_kinds: &'a [ProprietaryCompressionBehaviorKind],
    local_test_plan_ref: Option<&'a str>,
    quarantine_ref: Option<&'a str>,
    clean_room_note_ref: Option<&'a str>,
    attribution_ref: Option<&'a str>,
    model_inventory_candidate_ref: Option<&'a str>,
    benchmark_claim_count: u64,
}

fn overlay(
    graph: &SourceSignalGraph,
    spec: OverlaySpec<'_>,
) -> ProprietaryCompressionSourceOverlay {
    ProprietaryCompressionSourceOverlay {
        overlay_id: spec.overlay_id.to_string(),
        source_id: spec.source_id.to_string(),
        source_digest: digest_for(graph, spec.source_id),
        source_kind: spec.source_kind,
        source_locator: format!("fixture://provenance/{}", spec.source_id),
        observed_at_utc: "2026-06-06T00:00:00Z".to_string(),
        license_class: spec.license_class,
        import_mode: spec.import_mode,
        allowed_action: spec.allowed_action,
        dependency_count: 3,
        transitive_unknown_dependency_count: 0,
        benchmark_claim_count: spec.benchmark_claim_count,
        extracted_behaviors: spec
            .behavior_kinds
            .iter()
            .enumerate()
            .map(|(index, kind)| behavior(spec.overlay_id, index, *kind))
            .collect(),
        local_test_plan_ref: spec.local_test_plan_ref.map(str::to_string),
        quarantine_ref: spec.quarantine_ref.map(str::to_string),
        clean_room_note_ref: spec.clean_room_note_ref.map(str::to_string),
        attribution_ref: spec.attribution_ref.map(str::to_string),
        model_inventory_candidate_ref: spec.model_inventory_candidate_ref.map(str::to_string),
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        byte_scope: ProprietaryCompressionByteScope::metadata_only(1_024, 16_384),
        proof_refs: proof_refs(spec.overlay_id),
    }
}

fn behavior(
    overlay_id: &str,
    index: usize,
    kind: ProprietaryCompressionBehaviorKind,
) -> ProprietaryCompressionExtractedBehavior {
    ProprietaryCompressionExtractedBehavior {
        behavior_id: format!("{overlay_id}:behavior:{index}"),
        kind,
        summary_ref: format!("summary:{overlay_id}:{index}"),
        evidence_ref: format!("evidence:{overlay_id}:{index}"),
        uses_verbatim_code: false,
    }
}

fn proof_refs(overlay_id: &str) -> ProprietaryCompressionProofRefs {
    ProprietaryCompressionProofRefs {
        falsifier_ref: format!("falsifier:proprietary-compression:{overlay_id}"),
        rollback_ref: format!("rollback:proprietary-compression:{overlay_id}"),
        run_event_log_ref: format!("run_event_log:proprietary-compression:{overlay_id}"),
        answer_packet_ref: format!("answer_packet:proprietary-compression:{overlay_id}"),
        compatibility_fence_ref: format!("compat:proprietary-compression:{overlay_id}"),
    }
}

fn build_gate(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    overlays: Vec<ProprietaryCompressionSourceOverlay>,
) -> Result<
    ProprietaryCompressionProvenanceGate,
    agent_core::uas::ProprietaryCompressionProvenanceError,
> {
    ProprietaryCompressionProvenanceGate::from_sources(
        graph,
        inventory,
        overlays,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        GATE_METADATA_BYTES,
        true,
        true,
        true,
        true,
        CREATED_AT_MS,
    )
}

fn gate_with_metadata_bytes_is_err(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    overlays: &[ProprietaryCompressionSourceOverlay],
    metadata_bytes: u64,
) -> bool {
    ProprietaryCompressionProvenanceGate::from_sources(
        graph,
        inventory,
        overlays.to_vec(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        metadata_bytes,
        true,
        true,
        true,
        true,
        CREATED_AT_MS,
    )
    .is_err()
}

fn gate_with_layer_flags_is_err(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    overlays: &[ProprietaryCompressionSourceOverlay],
    l1_l2_l3_separated: bool,
) -> bool {
    ProprietaryCompressionProvenanceGate::from_sources(
        graph,
        inventory,
        overlays.to_vec(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        GATE_METADATA_BYTES,
        l1_l2_l3_separated,
        true,
        true,
        true,
        CREATED_AT_MS,
    )
    .is_err()
}

fn reject_overlay(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    overlays: &[ProprietaryCompressionSourceOverlay],
    mutate: impl FnOnce(&mut ProprietaryCompressionSourceOverlay),
) -> bool {
    reject_named_overlay(graph, inventory, overlays, &overlays[0].overlay_id, mutate)
}

fn reject_named_overlay(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    overlays: &[ProprietaryCompressionSourceOverlay],
    overlay_id: &str,
    mutate: impl FnOnce(&mut ProprietaryCompressionSourceOverlay),
) -> bool {
    let mut mutated = overlays.to_vec();
    let Some(overlay) = mutated
        .iter_mut()
        .find(|overlay| overlay.overlay_id == overlay_id)
    else {
        return false;
    };
    mutate(overlay);
    build_gate(graph, inventory, mutated).is_err()
}

fn reject_overlays(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    overlays: &[ProprietaryCompressionSourceOverlay],
    mutate: impl FnOnce(&mut Vec<ProprietaryCompressionSourceOverlay>),
) -> bool {
    let mut mutated = overlays.to_vec();
    mutate(&mut mutated);
    build_gate(graph, inventory, mutated).is_err()
}

fn digest_for(graph: &SourceSignalGraph, source_id: &str) -> String {
    graph
        .source_cards
        .iter()
        .find(|card| card.source_id == source_id)
        .map(|card| card.digest.clone())
        .unwrap_or_else(|| digest(source_id))
}

fn digest(seed: &str) -> String {
    format!("blake3:{}", blake3::hash(seed.as_bytes()).to_hex())
}

fn red_pass(red_results: &[(&'static str, bool)], name: &str) -> bool {
    red_results
        .iter()
        .find(|(axis, _)| *axis == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    pass: bool,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Bool(pass),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: u64,
    threshold: u64,
    operator: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: "count".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::json!(threshold),
            unit: "count".to_string(),
        },
    );
    let pass = match operator {
        ">=" => value >= threshold,
        "<=" => value <= threshold,
        "==" => value == threshold,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), pass);
}

#[allow(dead_code)]
fn unique_overlay_ids(overlays: &[ProprietaryCompressionSourceOverlay]) -> bool {
    let mut ids = HashSet::new();
    overlays
        .iter()
        .all(|overlay| ids.insert(overlay.overlay_id.as_str()))
}
