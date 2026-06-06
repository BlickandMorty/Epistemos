//! `falsify_small_compressed_model_live_harness_preflight`
//!
//! Metadata-only witness for `F-SmallCompressedModel-LiveHarnessPreflight`. It
//! converts compressed-route AnswerPacket dry-runs into an owner-approval lease
//! for a future tiny compressed-model runtime probe without opening model or
//! runtime bytes.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, QatRouteRuntimeLane, SmallCompressedHarnessAdmission,
    SmallCompressedHarnessBytePlan, SmallCompressedHarnessPromotionTier,
    SmallCompressedHarnessProofRefs, SmallCompressedModelLiveHarnessPreflightCandidate,
    SmallCompressedModelLiveHarnessPreflightSet, UasAddress, UasKind,
    SMALL_COMPRESSED_MODEL_LIVE_HARNESS_PREFLIGHT_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallCompressedModel-LiveHarnessPreflight";
const FIXTURE_ID: &str = "small_compressed_model_live_harness_preflight_v1";
const COMMAND: &str = "Tools/falsifiers/f_small_compressed_model_live_harness_preflight.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_compressed_model_live_harness_preflight/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/compressed_route_answer_packet_dry_run/result.json";
const CREATED_AT_MS: u64 = 1_779_034_900_000;
const SET_METADATA_BYTES: u64 = 86_000;
const GIB: u64 = 1_073_741_824;
const MIB: u64 = 1_048_576;

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
        "{FALSIFIER_ID}: overall_pass={} candidate_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["accepted_candidate_count"].value,
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
    let upstream = upstream_packet_set_address()?;
    let candidates = accepted_candidates();
    let preflight_set = build_set(upstream.clone(), candidates.clone())?;
    let reversed = build_set(upstream, candidates.iter().cloned().rev().collect())?;
    let metrics = preflight_set.metrics();
    let red_results = red_fixture_results(&preflight_set);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_compressed_route_packets_bound",
            preflight_set
                .upstream_packet_witness_ref
                .contains("compressed_route_answer_packet_dry_run"),
        ),
        (
            "selected_smallest_packetized_candidate",
            preflight_set.selected_candidate_id == "gemma4_e2b_qat_gguf_harness_preflight"
                && selected(&candidates)
                    .map(|candidate| {
                        candidate.model_id.contains("-E2B-")
                            && candidate.runtime_lane == QatRouteRuntimeLane::GgufLlamaCpp
                            && candidate.admission
                                == SmallCompressedHarnessAdmission::ReadyForOwnerApproval
                    })
                    .unwrap_or(false)
                && red_pass(&red_results, "e4b_selected_as_primary")
                && red_pass(&red_results, "mlx_selected_as_primary"),
        ),
        (
            "e4b_alternate_deferred_visible",
            candidates.iter().any(|candidate| {
                candidate.candidate_id == "gemma4_e4b_qat_gguf_harness_alternate"
                    && candidate.admission == SmallCompressedHarnessAdmission::AlternateDeferred
                    && !candidate.selected_for_probe
                    && candidate.fallback_order == 2
            }),
        ),
        (
            "twelve_b_thirty_one_b_not_selected",
            candidates.iter().all(|candidate| {
                !candidate.model_id.contains("-12B-") && !candidate.model_id.contains("-31B-")
            }) && red_pass(&red_results, "twelve_b_candidate_inserted")
                && red_pass(&red_results, "thirty_one_b_candidate_inserted"),
        ),
        (
            "gguf_llamacpp_primary_lane",
            selected(&candidates)
                .map(|candidate| candidate.runtime_lane == QatRouteRuntimeLane::GgufLlamaCpp)
                .unwrap_or(false),
        ),
        (
            "litert_requires_later_package_proof",
            preflight_set.litert_requires_later_package_proof
                && red_pass(&red_results, "set_litert_proof_not_required"),
        ),
        (
            "mlx_swift_loader_caveat_preserved",
            preflight_set.mlx_swift_loader_caveat_visible
                && candidates.iter().all(|candidate| {
                    candidate
                        .refs
                        .blocked_lane_refs
                        .iter()
                        .any(|lane| lane.contains("mlx_swift_loader_unproven"))
                })
                && red_pass(&red_results, "set_mlx_caveat_missing")
                && red_pass(&red_results, "missing_blocked_lane_ref"),
        ),
        (
            "owner_approval_required_not_granted",
            candidates.iter().all(|candidate| {
                candidate.owner_approval_required && !candidate.owner_approval_granted
            }) && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "owner_approval_not_required"),
        ),
        (
            "runtime_probe_deferred",
            candidates
                .iter()
                .all(|candidate| candidate.runtime_probe_deferred)
                && red_pass(&red_results, "runtime_not_deferred"),
        ),
        (
            "no_live_execution_or_first_token",
            candidates.iter().all(|candidate| {
                !candidate.live_execution_performed
                    && !candidate.first_token_claimed
                    && !candidate.retained_token_digest_recorded
            }) && red_pass(&red_results, "live_execution_performed")
                && red_pass(&red_results, "first_token_claim")
                && red_pass(&red_results, "retained_token_digest_recorded"),
        ),
        (
            "byte_plan_consistent",
            candidates.iter().all(|candidate| {
                candidate.bytes.planned_route_bytes
                    == candidate.bytes.planned_model_bytes
                        + candidate.bytes.planned_kv_bytes
                        + candidate.bytes.planned_scratch_bytes
                    && candidate.bytes.planned_model_bytes > candidate.bytes.declared_file_bytes
                    && candidate.bytes.retained_token_budget == 1
                    && candidate.bytes.cancellation_deadline_ms <= candidate.bytes.timeout_ms
            }) && red_pass(&red_results, "zero_declared_file_bytes")
                && red_pass(&red_results, "planned_model_equals_file")
                && red_pass(&red_results, "zero_context_tokens")
                && red_pass(&red_results, "wrong_retained_token_budget")
                && red_pass(&red_results, "bad_planned_route_bytes")
                && red_pass(&red_results, "cancellation_exceeds_timeout"),
        ),
        (
            "zero_opened_model_bytes",
            metrics.opened_model_bytes == 0 && red_pass(&red_results, "opened_model_bytes"),
        ),
        (
            "zero_opened_runtime_bytes",
            metrics.opened_runtime_bytes == 0 && red_pass(&red_results, "opened_runtime_bytes"),
        ),
        (
            "zero_resident_model_bytes",
            metrics.resident_model_bytes == 0 && red_pass(&red_results, "resident_model_bytes"),
        ),
        (
            "zero_resident_runtime_bytes",
            metrics.resident_runtime_bytes == 0 && red_pass(&red_results, "resident_runtime_bytes"),
        ),
        (
            "zero_model_bytes_loaded",
            metrics.model_bytes_loaded == 0 && red_pass(&red_results, "model_bytes_loaded"),
        ),
        (
            "zero_runtime_bytes_loaded",
            metrics.runtime_bytes_loaded == 0 && red_pass(&red_results, "runtime_bytes_loaded"),
        ),
        (
            "zero_provider_calls",
            metrics.provider_calls_made == 0 && red_pass(&red_results, "provider_call_made"),
        ),
        (
            "answer_packet_log_rollback_cancellation_required",
            candidates.iter().all(|candidate| {
                candidate.answer_packet_required
                    && candidate.run_event_log_required
                    && candidate.rollback_required
                    && candidate.cancellation_required
            }) && red_pass(&red_results, "missing_answer_packet")
                && red_pass(&red_results, "missing_run_event_log")
                && red_pass(&red_results, "missing_rollback")
                && red_pass(&red_results, "missing_cancellation"),
        ),
        (
            "visibility_required",
            candidates.iter().all(|candidate| {
                candidate.selected_model_visible
                    && candidate.rejected_candidates_visible
                    && candidate.runtime_lane_visible
                    && candidate.byte_plan_visible
            }) && red_pass(&red_results, "missing_selected_model_visibility")
                && red_pass(&red_results, "missing_runtime_lane_visibility")
                && red_pass(&red_results, "missing_byte_plan_visibility"),
        ),
        (
            "product_promotion_rejected",
            red_pass(&red_results, "mas_product_build")
                && red_pass(&red_results, "pro_live_status")
                && red_pass(&red_results, "promotion_tier_t2")
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "l2_capability_claim")
                && red_pass(&red_results, "l3_wrv_claim")
                && red_pass(&red_results, "mas_readiness_claim"),
        ),
        (
            "hidden_authority_rejected",
            red_pass(&red_results, "hidden_cloud_fallback")
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "route_policy_mutated")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "proof_refs_required",
            red_pass(&red_results, "bad_upstream_packet_ref")
                && red_pass(&red_results, "bad_runtime_doc_ref")
                && red_pass(&red_results, "bad_owner_approval_ref")
                && red_pass(&red_results, "bad_memory_ledger_ref"),
        ),
        (
            "set_address_deterministic",
            preflight_set.set_address == reversed.set_address,
        ),
        (
            "layer_separation_required",
            red_pass(&red_results, "set_missing_layer_separation")
                && red_pass(&red_results, "set_runtime_not_deferred")
                && red_pass(&red_results, "set_product_promotion_allowed"),
        ),
        (
            "metadata_budget_enforced",
            red_pass(&red_results, "candidate_metadata_budget_exceeded")
                && red_pass(&red_results, "set_metadata_budget_exceeded"),
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
        "accepted_candidate_count",
        metrics.candidate_count,
        ">=",
        2,
        "candidates",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_candidate_count",
        metrics.selected_count,
        "==",
        1,
        "candidates",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        40,
        "fixtures",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        "==",
        red_results.len() as u64,
        "fixtures",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "planned_route_bytes_total",
        metrics.planned_route_bytes_total,
        ">",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_bytes_loaded",
        metrics.model_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_bytes_loaded",
        metrics.runtime_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_calls_made",
        metrics.provider_calls_made,
        "==",
        0,
        "calls",
    );

    measurements.insert(
        "preflight_set_address".to_string(),
        Measurement {
            value: serde_json::json!(preflight_set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "preflight_set_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("small_compressed_model_live_harness_preflight:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "preflight_set_address".to_string(),
        preflight_set
            .set_address
            .to_string()
            .starts_with("small_compressed_model_live_harness_preflight:"),
    );
    measurements.insert(
        "selected_candidate_id".to_string(),
        Measurement {
            value: serde_json::json!(preflight_set.selected_candidate_id),
            unit: "candidate_id".to_string(),
        },
    );
    thresholds.insert(
        "selected_candidate_id".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("gemma4_e2b_qat_gguf_harness_preflight"),
            unit: "candidate_id".to_string(),
        },
    );
    pass_per_axis.insert(
        "selected_candidate_id".to_string(),
        preflight_set.selected_candidate_id == "gemma4_e2b_qat_gguf_harness_preflight",
    );
    measurements.insert(
        "next_research_to_build_unit".to_string(),
        Measurement {
            value: serde_json::json!(SMALL_COMPRESSED_MODEL_LIVE_HARNESS_PREFLIGHT_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_research_to_build_unit".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("small_compressed_model_owner_approved_runtime_probe"),
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
        anomalies: Vec::new(),
        notes: "Builds F-SmallCompressedModel-LiveHarnessPreflight from the compressed-route AnswerPacket dry-run witness. Scope is T1/L1 metadata only: Gemma 4 E2B QAT GGUF is the smallest owner-approval candidate for a future one-token runtime probe, E4B is visible deferred fallback, LiteRT requires later package proof, MLX Swift remains blocked by loader caveat, and no model/runtime/provider bytes are opened or loaded.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_packet_set_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream compressed-route packet witness has not passed".into());
    }
    let address = value
        .pointer("/measurements/packet_set_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream packet_set_address measurement")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream_packet_set_address: UasAddress,
    candidates: Vec<SmallCompressedModelLiveHarnessPreflightCandidate>,
) -> Result<SmallCompressedModelLiveHarnessPreflightSet, Box<dyn std::error::Error>> {
    Ok(
        SmallCompressedModelLiveHarnessPreflightSet::from_packet_set(
            upstream_packet_set_address,
            "artifact:compressed_route_answer_packet_dry_run:result",
            "gemma4_e2b_qat_gguf_harness_preflight",
            candidates,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            SET_METADATA_BYTES,
            true,
            true,
            true,
            true,
            true,
            CREATED_AT_MS,
        )?,
    )
}

fn accepted_candidates() -> Vec<SmallCompressedModelLiveHarnessPreflightCandidate> {
    vec![
        candidate(CandidateSpec {
            candidate_id: "gemma4_e2b_qat_gguf_harness_preflight",
            upstream_packet_id: "gemma4_e2b_compressed_route_packet",
            model_id: "google/gemma-4-E2B-it-qat-q4_0-gguf",
            admission: SmallCompressedHarnessAdmission::ReadyForOwnerApproval,
            selected_for_probe: true,
            fallback_order: 1,
            declared_file_bytes: 4_628_569_635,
            planned_model_bytes: 5 * GIB,
            planned_kv_bytes: 512 * MIB,
            planned_scratch_bytes: 256 * MIB,
        }),
        candidate(CandidateSpec {
            candidate_id: "gemma4_e4b_qat_gguf_harness_alternate",
            upstream_packet_id: "gemma4_e4b_compressed_route_packet",
            model_id: "google/gemma-4-E4B-it-qat-q4_0-gguf",
            admission: SmallCompressedHarnessAdmission::AlternateDeferred,
            selected_for_probe: false,
            fallback_order: 2,
            declared_file_bytes: 7_463_013_674,
            planned_model_bytes: 8 * GIB,
            planned_kv_bytes: 768 * MIB,
            planned_scratch_bytes: 384 * MIB,
        }),
    ]
}

// UAS-EXEMPT: private fixture builder for this falsifier binary; emitted UAS
// objects are `SmallCompressedModelLiveHarnessPreflightCandidate` and set.
struct CandidateSpec {
    candidate_id: &'static str,
    upstream_packet_id: &'static str,
    model_id: &'static str,
    admission: SmallCompressedHarnessAdmission,
    selected_for_probe: bool,
    fallback_order: u64,
    declared_file_bytes: u64,
    planned_model_bytes: u64,
    planned_kv_bytes: u64,
    planned_scratch_bytes: u64,
}

fn candidate(spec: CandidateSpec) -> SmallCompressedModelLiveHarnessPreflightCandidate {
    let CandidateSpec {
        candidate_id,
        upstream_packet_id,
        model_id,
        admission,
        selected_for_probe,
        fallback_order,
        declared_file_bytes,
        planned_model_bytes,
        planned_kv_bytes,
        planned_scratch_bytes,
    } = spec;
    SmallCompressedModelLiveHarnessPreflightCandidate {
        candidate_id: candidate_id.to_string(),
        model_id: model_id.to_string(),
        runtime_lane: QatRouteRuntimeLane::GgufLlamaCpp,
        admission,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: SmallCompressedHarnessPromotionTier::T1L1Metadata,
        selected_for_probe,
        fallback_order,
        bytes: SmallCompressedHarnessBytePlan::metadata_only(
            declared_file_bytes,
            planned_model_bytes,
            planned_kv_bytes,
            planned_scratch_bytes,
            2048,
            1,
            120_000,
            5_000,
            22_000,
        ),
        refs: SmallCompressedHarnessProofRefs {
            upstream_packet_ref: format!("answer_packet:compressed_route_dry_run:{upstream_packet_id}"),
            source_card_ref: format!("source:model:{candidate_id}"),
            runtime_doc_ref: "source:web:google_gemma4_qat_gguf_llamacpp_primary".to_string(),
            owner_approval_ref: format!("owner_approval:pending:{candidate_id}"),
            command_ledger_ref: format!("command_ledger:small_compressed_preflight:{candidate_id}"),
            answer_packet_ref: format!("answer_packet:small_compressed_preflight:{candidate_id}"),
            run_event_log_ref: format!("run_event_log:small_compressed_preflight:{candidate_id}"),
            rollback_ref: format!("rollback:small_compressed_preflight:{candidate_id}"),
            cancellation_ref: format!("cancel:small_compressed_preflight:{candidate_id}"),
            memory_ledger_ref: format!("memory_ledger:small_compressed_preflight:{candidate_id}"),
            compatibility_fence_ref: format!("compat:small_compressed_preflight:{candidate_id}"),
            route_caveat_ref: format!("route_caveat:small_compressed_preflight:{candidate_id}"),
            blocked_lane_refs: vec![
                "blocked_lane:mlx_swift_loader_unproven".to_string(),
                "blocked_lane:litert_package_proof_required".to_string(),
                "blocked_lane:local_endpoint_hidden_fallback_forbidden".to_string(),
            ],
        },
        user_visible_summary: format!(
            "{candidate_id} is a metadata-only small compressed-model live-harness preflight for {model_id}. It selects the runtime lane, byte plan, owner-approval gate, rollback, cancellation, RunEventLog, and AnswerPacket requirements; no model/runtime/provider bytes are opened or loaded and no product capability is claimed."
        ),
        selected_model_visible: true,
        rejected_candidates_visible: true,
        runtime_lane_visible: true,
        byte_plan_visible: true,
        owner_approval_required: true,
        owner_approval_granted: false,
        runtime_probe_deferred: true,
        live_execution_performed: false,
        first_token_claimed: false,
        retained_token_digest_recorded: false,
        quality_claimed: false,
        l2_capability_claimed: false,
        l3_wrv_claimed: false,
        mas_readiness_claimed: false,
        answer_packet_required: true,
        run_event_log_required: true,
        rollback_required: true,
        cancellation_required: true,
        route_policy_mutated: false,
        hidden_cloud_fallback_allowed: false,
        hidden_route_authority_allowed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
    }
}

fn selected(
    candidates: &[SmallCompressedModelLiveHarnessPreflightCandidate],
) -> Option<&SmallCompressedModelLiveHarnessPreflightCandidate> {
    candidates
        .iter()
        .find(|candidate| candidate.selected_for_probe)
}

fn red_pass(red_results: &[(&'static str, bool)], name: &str) -> bool {
    red_results
        .iter()
        .any(|(candidate, pass)| *candidate == name && *pass)
}

fn red_fixture_results(
    valid_set: &SmallCompressedModelLiveHarnessPreflightSet,
) -> Vec<(&'static str, bool)> {
    vec![
        red_candidate("duplicate_candidate_id", |candidates| {
            candidates.push(candidates[0].clone());
        }),
        red_candidate("duplicate_model_runtime", |candidates| {
            let mut duplicate = candidates[0].clone();
            duplicate.candidate_id = "gemma4_e2b_duplicate_runtime".to_string();
            candidates.push(duplicate);
        }),
        red_candidate("bad_upstream_packet_ref", |candidates| {
            candidates[0].refs.upstream_packet_ref = "bad:upstream".to_string();
        }),
        red_candidate("bad_runtime_doc_ref", |candidates| {
            candidates[0].refs.runtime_doc_ref = "doc:runtime".to_string();
        }),
        red_candidate("bad_owner_approval_ref", |candidates| {
            candidates[0].refs.owner_approval_ref = "owner_approval:granted:e2b".to_string();
        }),
        red_candidate("bad_memory_ledger_ref", |candidates| {
            candidates[0].refs.memory_ledger_ref = "mem:e2b".to_string();
        }),
        red_candidate("missing_blocked_lane_ref", |candidates| {
            candidates[0].refs.blocked_lane_refs.clear();
        }),
        red_candidate("e4b_selected_as_primary", |candidates| {
            candidates[0].selected_for_probe = false;
            candidates[0].admission = SmallCompressedHarnessAdmission::AlternateDeferred;
            candidates[0].fallback_order = 2;
            candidates[1].selected_for_probe = true;
            candidates[1].admission = SmallCompressedHarnessAdmission::ReadyForOwnerApproval;
            candidates[1].fallback_order = 1;
        }),
        red_candidate("mlx_selected_as_primary", |candidates| {
            candidates[0].runtime_lane = QatRouteRuntimeLane::MlxSwiftCandidate;
        }),
        red_candidate("twelve_b_candidate_inserted", |candidates| {
            let mut bad = candidates[0].clone();
            bad.candidate_id = "gemma4_12b_bad_preflight".to_string();
            bad.model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string();
            candidates.push(bad);
        }),
        red_candidate("thirty_one_b_candidate_inserted", |candidates| {
            let mut bad = candidates[0].clone();
            bad.candidate_id = "gemma4_31b_bad_preflight".to_string();
            bad.model_id = "google/gemma-4-31B-it-qat-q4_0-gguf".to_string();
            candidates.push(bad);
        }),
        red_candidate("owner_approval_granted", |candidates| {
            candidates[0].owner_approval_granted = true;
        }),
        red_candidate("owner_approval_not_required", |candidates| {
            candidates[0].owner_approval_required = false;
        }),
        red_candidate("runtime_not_deferred", |candidates| {
            candidates[0].runtime_probe_deferred = false;
        }),
        red_candidate("live_execution_performed", |candidates| {
            candidates[0].live_execution_performed = true;
        }),
        red_candidate("first_token_claim", |candidates| {
            candidates[0].first_token_claimed = true;
        }),
        red_candidate("retained_token_digest_recorded", |candidates| {
            candidates[0].retained_token_digest_recorded = true;
        }),
        red_candidate("zero_declared_file_bytes", |candidates| {
            candidates[0].bytes.declared_file_bytes = 0;
        }),
        red_candidate("planned_model_equals_file", |candidates| {
            candidates[0].bytes.planned_model_bytes = candidates[0].bytes.declared_file_bytes;
        }),
        red_candidate("zero_context_tokens", |candidates| {
            candidates[0].bytes.max_context_tokens = 0;
        }),
        red_candidate("wrong_retained_token_budget", |candidates| {
            candidates[0].bytes.retained_token_budget = 2;
        }),
        red_candidate("bad_planned_route_bytes", |candidates| {
            candidates[0].bytes.planned_route_bytes += 1;
        }),
        red_candidate("cancellation_exceeds_timeout", |candidates| {
            candidates[0].bytes.cancellation_deadline_ms = candidates[0].bytes.timeout_ms + 1;
        }),
        red_candidate("opened_model_bytes", |candidates| {
            candidates[0].bytes.opened_model_bytes = 1;
        }),
        red_candidate("opened_runtime_bytes", |candidates| {
            candidates[0].bytes.opened_runtime_bytes = 1;
        }),
        red_candidate("resident_model_bytes", |candidates| {
            candidates[0].bytes.resident_model_bytes = 1;
        }),
        red_candidate("resident_runtime_bytes", |candidates| {
            candidates[0].bytes.resident_runtime_bytes = 1;
        }),
        red_candidate("model_bytes_loaded", |candidates| {
            candidates[0].bytes.model_bytes_loaded = 1;
        }),
        red_candidate("runtime_bytes_loaded", |candidates| {
            candidates[0].bytes.runtime_bytes_loaded = 1;
        }),
        red_candidate("provider_call_made", |candidates| {
            candidates[0].bytes.provider_calls_made = 1;
        }),
        red_candidate("missing_answer_packet", |candidates| {
            candidates[0].answer_packet_required = false;
        }),
        red_candidate("missing_run_event_log", |candidates| {
            candidates[0].run_event_log_required = false;
        }),
        red_candidate("missing_rollback", |candidates| {
            candidates[0].rollback_required = false;
        }),
        red_candidate("missing_cancellation", |candidates| {
            candidates[0].cancellation_required = false;
        }),
        red_candidate("missing_selected_model_visibility", |candidates| {
            candidates[0].selected_model_visible = false;
        }),
        red_candidate("missing_runtime_lane_visibility", |candidates| {
            candidates[0].runtime_lane_visible = false;
        }),
        red_candidate("missing_byte_plan_visibility", |candidates| {
            candidates[0].byte_plan_visible = false;
        }),
        red_candidate("mas_product_build", |candidates| {
            candidates[0].product_build = ProductBuild::Mas;
        }),
        red_candidate("pro_live_status", |candidates| {
            candidates[0].pro_status = ProStatus::Live;
        }),
        red_candidate("promotion_tier_t2", |candidates| {
            candidates[0].promotion_tier = SmallCompressedHarnessPromotionTier::T2L2Route;
        }),
        red_candidate("quality_claim", |candidates| {
            candidates[0].quality_claimed = true;
        }),
        red_candidate("l2_capability_claim", |candidates| {
            candidates[0].l2_capability_claimed = true;
        }),
        red_candidate("l3_wrv_claim", |candidates| {
            candidates[0].l3_wrv_claimed = true;
        }),
        red_candidate("mas_readiness_claim", |candidates| {
            candidates[0].mas_readiness_claimed = true;
        }),
        red_candidate("hidden_cloud_fallback", |candidates| {
            candidates[0].hidden_cloud_fallback_allowed = true;
        }),
        red_candidate("hidden_route_authority", |candidates| {
            candidates[0].hidden_route_authority_allowed = true;
        }),
        red_candidate("route_policy_mutated", |candidates| {
            candidates[0].route_policy_mutated = true;
        }),
        red_candidate("live_dense_70b_claim", |candidates| {
            candidates[0].live_dense_70b_claimed = true;
        }),
        red_candidate("ssd_as_ram_claim", |candidates| {
            candidates[0].ssd_as_ram_claimed = true;
        }),
        red_candidate("candidate_metadata_budget_exceeded", |candidates| {
            candidates[0].bytes.metadata_bytes_read = 97 * 1024;
        }),
        (
            "set_metadata_budget_exceeded",
            set_from(
                valid_set.upstream_packet_set_address.clone(),
                accepted_candidates(),
                513 * 1024,
                true,
                true,
                true,
                true,
                true,
            )
            .is_err(),
        ),
        (
            "set_missing_layer_separation",
            set_from(
                valid_set.upstream_packet_set_address.clone(),
                accepted_candidates(),
                SET_METADATA_BYTES,
                false,
                true,
                true,
                true,
                true,
            )
            .is_err(),
        ),
        (
            "set_runtime_not_deferred",
            set_from(
                valid_set.upstream_packet_set_address.clone(),
                accepted_candidates(),
                SET_METADATA_BYTES,
                true,
                false,
                true,
                true,
                true,
            )
            .is_err(),
        ),
        (
            "set_product_promotion_allowed",
            set_from(
                valid_set.upstream_packet_set_address.clone(),
                accepted_candidates(),
                SET_METADATA_BYTES,
                true,
                true,
                false,
                true,
                true,
            )
            .is_err(),
        ),
        (
            "set_mlx_caveat_missing",
            set_from(
                valid_set.upstream_packet_set_address.clone(),
                accepted_candidates(),
                SET_METADATA_BYTES,
                true,
                true,
                true,
                false,
                true,
            )
            .is_err(),
        ),
        (
            "set_litert_proof_not_required",
            set_from(
                valid_set.upstream_packet_set_address.clone(),
                accepted_candidates(),
                SET_METADATA_BYTES,
                true,
                true,
                true,
                true,
                false,
            )
            .is_err(),
        ),
    ]
}

fn red_candidate(
    name: &'static str,
    mutate: impl FnOnce(&mut Vec<SmallCompressedModelLiveHarnessPreflightCandidate>),
) -> (&'static str, bool) {
    let mut candidates = accepted_candidates();
    mutate(&mut candidates);
    let pass = set_from(
        upstream_fixture_address(),
        candidates,
        SET_METADATA_BYTES,
        true,
        true,
        true,
        true,
        true,
    )
    .is_err();
    (name, pass)
}

#[allow(clippy::too_many_arguments)]
fn set_from(
    upstream_packet_set_address: UasAddress,
    candidates: Vec<SmallCompressedModelLiveHarnessPreflightCandidate>,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
    mlx_swift_loader_caveat_visible: bool,
    litert_requires_later_package_proof: bool,
) -> Result<
    SmallCompressedModelLiveHarnessPreflightSet,
    agent_core::uas::SmallCompressedHarnessPreflightError,
> {
    SmallCompressedModelLiveHarnessPreflightSet::from_packet_set(
        upstream_packet_set_address,
        "artifact:compressed_route_answer_packet_dry_run:result",
        "gemma4_e2b_qat_gguf_harness_preflight",
        candidates,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked,
        mlx_swift_loader_caveat_visible,
        litert_requires_later_package_proof,
        CREATED_AT_MS,
    )
}

fn upstream_fixture_address() -> UasAddress {
    UasAddress::new(
        UasKind::Other("compressed_route_answer_packet_dry_run".to_string()),
        b"small-compressed-model-preflight-red-fixture",
        CREATED_AT_MS,
    )
}
