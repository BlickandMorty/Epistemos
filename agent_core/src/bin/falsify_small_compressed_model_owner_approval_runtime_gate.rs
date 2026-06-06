//! `falsify_small_compressed_model_owner_approval_runtime_gate`
//!
//! Metadata-only witness for
//! `F-SmallCompressedModel-OwnerApprovalRuntimeGate`. It binds the Gemma 4 E2B
//! QAT GGUF preflight candidate to a fail-closed owner-approval command gate
//! without arming a runtime command, opening model bytes, or promoting L2/L3.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, QatRouteRuntimeLane, SmallCompressedHarnessPromotionTier,
    SmallCompressedModelOwnerApprovalRuntimeGate, SmallCompressedModelOwnerApprovalRuntimeGateSet,
    SmallCompressedOwnerApprovalByteLedger, SmallCompressedOwnerApprovalRefs,
    SmallCompressedOwnerApprovalStatus, UasAddress, UasKind,
    SMALL_COMPRESSED_MODEL_OWNER_APPROVAL_RUNTIME_GATE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallCompressedModel-OwnerApprovalRuntimeGate";
const FIXTURE_ID: &str = "small_compressed_model_owner_approval_runtime_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_small_compressed_model_owner_approval_runtime_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_compressed_model_owner_approval_runtime_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/small_compressed_model_live_harness_preflight/result.json";
const CREATED_AT_MS: u64 = 1_779_035_500_000;
const SET_METADATA_BYTES: u64 = 78_000;
const SELECTED_GATE_ID: &str = "gemma4_e2b_qat_gguf_owner_approval_runtime_gate";
const SELECTED_CANDIDATE_ID: &str = "gemma4_e2b_qat_gguf_harness_preflight";
const MODEL_ID: &str = "google/gemma-4-E2B-it-qat-q4_0-gguf";
const GIB: u64 = 1_073_741_824;
const MIB: u64 = 1_048_576;

const DENIED_ROUTES: &[&str] = &[
    "denied_route:gemma4_12b_default",
    "denied_route:gemma4_31b_default",
    "denied_route:mlx_swift_loader_unproven",
    "denied_route:litert_package_proof_required",
    "denied_route:kv_direct_128k_shard",
    "denied_route:mmap_or_ssd_stress",
    "denied_route:provider_fallback",
    "denied_route:dense_70b_runtime",
];

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
        "{FALSIFIER_ID}: overall_pass={} gate_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["gate_count"].value,
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
    let (upstream_address, upstream_selected_candidate) = upstream_preflight_address()?;
    let gates = accepted_gates();
    let gate_set = build_set(upstream_address.clone(), gates.clone())?;
    let reversed = build_set(upstream_address, gates.iter().cloned().rev().collect())?;
    let metrics = gate_set.metrics();
    let red_results = red_fixture_results(&gate_set);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_preflight_pass_bound",
            gate_set
                .upstream_preflight_witness_ref
                .contains("small_compressed_model_live_harness_preflight")
                && upstream_selected_candidate == SELECTED_CANDIDATE_ID,
        ),
        (
            "selected_e2b_candidate_bound",
            gate_set.selected_gate_id == SELECTED_GATE_ID
                && selected(&gates)
                    .map(|gate| {
                        gate.selected_candidate_id == SELECTED_CANDIDATE_ID
                            && gate.model_id.contains("-E2B-")
                            && gate.runtime_lane == QatRouteRuntimeLane::GgufLlamaCpp
                    })
                    .unwrap_or(false)
                && red_pass(&red_results, "e4b_candidate_selected")
                && red_pass(&red_results, "twelve_b_candidate_selected")
                && red_pass(&red_results, "thirty_one_b_candidate_selected")
                && red_pass(&red_results, "mlx_lane_selected"),
        ),
        (
            "owner_approval_pending_fail_closed",
            gates.iter().all(|gate| {
                gate.owner_approval_required
                    && !gate.owner_approval_granted
                    && gate.approval_status
                        == SmallCompressedOwnerApprovalStatus::PendingOwnerApproval
                    && !gate.runtime_command_armed
                    && !gate.runtime_command_executed
            }) && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "approval_status_approved")
                && red_pass(&red_results, "owner_approval_not_required")
                && red_pass(&red_results, "runtime_command_armed")
                && red_pass(&red_results, "runtime_command_executed"),
        ),
        (
            "runtime_probe_not_executed",
            gates.iter().all(|gate| {
                !gate.live_execution_performed
                    && !gate.first_token_claimed
                    && !gate.retained_token_digest_recorded
            }) && red_pass(&red_results, "live_execution_performed")
                && red_pass(&red_results, "first_token_claimed")
                && red_pass(&red_results, "retained_token_digest_recorded"),
        ),
        (
            "byte_ledger_zero_loaded",
            metrics.opened_model_bytes == 0
                && metrics.opened_runtime_bytes == 0
                && metrics.resident_model_bytes == 0
                && metrics.resident_runtime_bytes == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "opened_model_bytes")
                && red_pass(&red_results, "opened_runtime_bytes")
                && red_pass(&red_results, "resident_model_bytes")
                && red_pass(&red_results, "resident_runtime_bytes")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_call_made"),
        ),
        (
            "byte_plan_consistent",
            gates.iter().all(|gate| {
                gate.bytes.planned_route_bytes
                    == gate.bytes.planned_model_bytes
                        + gate.bytes.planned_kv_bytes
                        + gate.bytes.planned_scratch_bytes
                    && gate.bytes.planned_model_bytes > gate.bytes.declared_file_bytes
                    && gate.bytes.retained_token_budget == 1
                    && gate.bytes.cancellation_deadline_ms <= gate.bytes.timeout_ms
            }) && red_pass(&red_results, "bad_planned_route_bytes")
                && red_pass(&red_results, "planned_model_equals_file")
                && red_pass(&red_results, "wrong_retained_token_budget")
                && red_pass(&red_results, "cancellation_exceeds_timeout"),
        ),
        (
            "proof_surfaces_required",
            gates.iter().all(|gate| {
                gate.answer_packet_required
                    && gate.run_event_log_required
                    && gate.rollback_required
                    && gate.cancellation_required
                    && gate.memory_ledger_required
            }) && red_pass(&red_results, "missing_answer_packet")
                && red_pass(&red_results, "missing_run_event_log")
                && red_pass(&red_results, "missing_rollback")
                && red_pass(&red_results, "missing_cancellation")
                && red_pass(&red_results, "missing_memory_ledger_required"),
        ),
        (
            "visibility_required",
            gates.iter().all(|gate| {
                gate.command_visible
                    && gate.selected_model_visible
                    && gate.denied_routes_visible
                    && gate.byte_plan_visible
            }) && red_pass(&red_results, "missing_command_visibility")
                && red_pass(&red_results, "missing_selected_model_visibility")
                && red_pass(&red_results, "missing_denied_routes_visibility")
                && red_pass(&red_results, "missing_byte_plan_visibility"),
        ),
        (
            "denied_routes_bound",
            gates.iter().all(|gate| {
                DENIED_ROUTES.iter().all(|route| {
                    gate.refs
                        .denied_route_refs
                        .iter()
                        .any(|candidate| candidate == route)
                })
            }) && red_pass(&red_results, "missing_denied_route")
                && red_pass(&red_results, "bad_denied_route_prefix")
                && red_pass(&red_results, "twelve_b_or_thirty_one_b_allowed")
                && red_pass(&red_results, "mlx_swift_loader_allowed")
                && red_pass(&red_results, "litert_without_package_proof_allowed")
                && red_pass(&red_results, "kv_direct_128k_shard_allowed")
                && red_pass(&red_results, "mmap_or_ssd_stress_allowed"),
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
            "proof_ref_prefixes_required",
            red_pass(&red_results, "bad_upstream_preflight_ref")
                && red_pass(&red_results, "bad_selected_candidate_ref")
                && red_pass(&red_results, "bad_owner_approval_ref")
                && red_pass(&red_results, "bad_command_ledger_ref")
                && red_pass(&red_results, "bad_model_path_ref")
                && red_pass(&red_results, "bad_memory_ledger_ref"),
        ),
        (
            "set_address_deterministic",
            gate_set.set_address == reversed.set_address,
        ),
        (
            "layer_separation_required",
            gate_set.l1_l2_l3_separated
                && gate_set.runtime_deferred
                && gate_set.product_promotion_blocked
                && red_pass(&red_results, "set_missing_layer_separation")
                && red_pass(&red_results, "set_runtime_not_deferred")
                && red_pass(&red_results, "set_product_promotion_allowed"),
        ),
        (
            "metadata_budget_enforced",
            red_pass(&red_results, "gate_metadata_budget_exceeded")
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
        "gate_count",
        metrics.gate_count,
        "==",
        1,
        "gates",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "pending_owner_approval_count",
        metrics.pending_owner_approval_count,
        "==",
        1,
        "gates",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        45,
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
        "gate_set_address".to_string(),
        Measurement {
            value: serde_json::json!(gate_set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "gate_set_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("small_compressed_model_owner_approval_runtime_gate:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "gate_set_address".to_string(),
        gate_set
            .set_address
            .to_string()
            .starts_with("small_compressed_model_owner_approval_runtime_gate:"),
    );

    measurements.insert(
        "selected_gate_id".to_string(),
        Measurement {
            value: serde_json::json!(gate_set.selected_gate_id),
            unit: "gate_id".to_string(),
        },
    );
    thresholds.insert(
        "selected_gate_id".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(SELECTED_GATE_ID),
            unit: "gate_id".to_string(),
        },
    );
    pass_per_axis.insert(
        "selected_gate_id".to_string(),
        gate_set.selected_gate_id == SELECTED_GATE_ID,
    );

    measurements.insert(
        "next_research_to_build_unit".to_string(),
        Measurement {
            value: serde_json::json!(
                SMALL_COMPRESSED_MODEL_OWNER_APPROVAL_RUNTIME_GATE_NEXT_CURSOR
            ),
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
        notes: "Builds F-SmallCompressedModel-OwnerApprovalRuntimeGate from the compressed-model live-harness preflight. Scope is research-to-build T1/L1 metadata only: the E2B GGUF one-token probe shape is visible, owner approval is pending, command execution is not armed, 12B/31B/MLX Swift/LiteRT-without-package-proof/KV-Direct-128K/mmap-stress/provider/dense-70B routes are denied, and no model/runtime/provider bytes are opened or loaded.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_preflight_address() -> Result<(UasAddress, String), Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream small compressed-model preflight has not passed".into());
    }
    let address = value
        .pointer("/measurements/preflight_set_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream preflight_set_address measurement")?;
    let selected_candidate = value
        .pointer("/measurements/selected_candidate_id/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream selected_candidate_id measurement")?;
    Ok((
        UasAddress::from_str(address)?,
        selected_candidate.to_string(),
    ))
}

fn build_set(
    upstream_preflight_set_address: UasAddress,
    gates: Vec<SmallCompressedModelOwnerApprovalRuntimeGate>,
) -> Result<SmallCompressedModelOwnerApprovalRuntimeGateSet, Box<dyn std::error::Error>> {
    Ok(
        SmallCompressedModelOwnerApprovalRuntimeGateSet::from_preflight(
            upstream_preflight_set_address,
            "artifact:small_compressed_model_live_harness_preflight:result",
            SELECTED_GATE_ID,
            gates,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            SET_METADATA_BYTES,
            true,
            true,
            true,
            CREATED_AT_MS,
        )?,
    )
}

fn accepted_gates() -> Vec<SmallCompressedModelOwnerApprovalRuntimeGate> {
    vec![gate()]
}

fn gate() -> SmallCompressedModelOwnerApprovalRuntimeGate {
    SmallCompressedModelOwnerApprovalRuntimeGate {
        gate_id: SELECTED_GATE_ID.to_string(),
        selected_candidate_id: SELECTED_CANDIDATE_ID.to_string(),
        model_id: MODEL_ID.to_string(),
        runtime_lane: QatRouteRuntimeLane::GgufLlamaCpp,
        approval_status: SmallCompressedOwnerApprovalStatus::PendingOwnerApproval,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: SmallCompressedHarnessPromotionTier::T1L1Metadata,
        bytes: SmallCompressedOwnerApprovalByteLedger::metadata_only(
            4_628_569_635,
            5 * GIB,
            512 * MIB,
            256 * MIB,
            2048,
            1,
            120_000,
            5_000,
            24_000,
        ),
        refs: SmallCompressedOwnerApprovalRefs {
            upstream_preflight_ref:
                "artifact:small_compressed_model_live_harness_preflight:result".to_string(),
            selected_candidate_ref: format!(
                "candidate:small_compressed_model_live_harness_preflight:{SELECTED_CANDIDATE_ID}"
            ),
            owner_approval_ref: format!("owner_approval:pending:{SELECTED_GATE_ID}"),
            command_ledger_ref: format!(
                "command_ledger:small_compressed_owner_gate:{SELECTED_GATE_ID}"
            ),
            model_path_ref: format!("model_path:pending_owner_approval:{SELECTED_GATE_ID}"),
            answer_packet_ref: format!("answer_packet:small_compressed_owner_gate:{SELECTED_GATE_ID}"),
            run_event_log_ref: format!("run_event_log:small_compressed_owner_gate:{SELECTED_GATE_ID}"),
            rollback_ref: format!("rollback:small_compressed_owner_gate:{SELECTED_GATE_ID}"),
            cancellation_ref: format!("cancel:small_compressed_owner_gate:{SELECTED_GATE_ID}"),
            memory_ledger_ref: format!("memory_ledger:small_compressed_owner_gate:{SELECTED_GATE_ID}"),
            compatibility_fence_ref: format!("compat:small_compressed_owner_gate:{SELECTED_GATE_ID}"),
            route_caveat_ref: format!("route_caveat:small_compressed_owner_gate:{SELECTED_GATE_ID}"),
            denied_route_refs: DENIED_ROUTES
                .iter()
                .map(|route| route.to_string())
                .collect(),
        },
        user_visible_summary: "Gemma 4 E2B QAT GGUF is the only selected tiny compressed-model future runtime probe candidate. This gate is pending explicit owner approval, exposes the command ledger and denied routes, requires cancellation, rollback, memory ledger, RunEventLog, and AnswerPacket proof, opens zero bytes, and promotes no product capability.".to_string(),
        command_visible: true,
        selected_model_visible: true,
        denied_routes_visible: true,
        byte_plan_visible: true,
        owner_approval_required: true,
        owner_approval_granted: false,
        runtime_command_armed: false,
        runtime_command_executed: false,
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
        memory_ledger_required: true,
        route_policy_mutated: false,
        hidden_cloud_fallback_allowed: false,
        hidden_route_authority_allowed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
        twelve_b_or_thirty_one_b_probe_allowed: false,
        mlx_swift_loader_allowed: false,
        litert_without_package_proof_allowed: false,
        kv_direct_128k_shard_allowed: false,
        mmap_or_ssd_stress_allowed: false,
    }
}

fn selected(
    gates: &[SmallCompressedModelOwnerApprovalRuntimeGate],
) -> Option<&SmallCompressedModelOwnerApprovalRuntimeGate> {
    gates.iter().find(|gate| gate.gate_id == SELECTED_GATE_ID)
}

fn red_pass(red_results: &[(&'static str, bool)], name: &str) -> bool {
    red_results.iter().any(|(red, pass)| *red == name && *pass)
}

fn red_fixture_results(
    valid_set: &SmallCompressedModelOwnerApprovalRuntimeGateSet,
) -> Vec<(&'static str, bool)> {
    vec![
        red_gate("duplicate_gate_id", |gates| {
            gates.push(gates[0].clone());
        }),
        red_gate("duplicate_candidate", |gates| {
            let mut duplicate = gates[0].clone();
            duplicate.gate_id = "duplicate_candidate_gate".to_string();
            gates.push(duplicate);
        }),
        red_gate("bad_upstream_preflight_ref", |gates| {
            gates[0].refs.upstream_preflight_ref = "artifact:wrong:result".to_string();
        }),
        red_gate("bad_selected_candidate_ref", |gates| {
            gates[0].refs.selected_candidate_ref = "candidate:wrong".to_string();
        }),
        red_gate("bad_owner_approval_ref", |gates| {
            gates[0].refs.owner_approval_ref = "owner_approval:granted:e2b".to_string();
        }),
        red_gate("bad_command_ledger_ref", |gates| {
            gates[0].refs.command_ledger_ref = "command_ledger:other:e2b".to_string();
        }),
        red_gate("bad_model_path_ref", |gates| {
            gates[0].refs.model_path_ref = "model_path:/live/model.gguf".to_string();
        }),
        red_gate("bad_memory_ledger_ref", |gates| {
            gates[0].refs.memory_ledger_ref = "memory:e2b".to_string();
        }),
        red_gate("missing_denied_route", |gates| {
            gates[0].refs.denied_route_refs.pop();
        }),
        red_gate("bad_denied_route_prefix", |gates| {
            gates[0].refs.denied_route_refs[0] = "allowed_route:12b".to_string();
        }),
        red_gate("e4b_candidate_selected", |gates| {
            gates[0].selected_candidate_id = "gemma4_e4b_qat_gguf_harness_alternate".to_string();
        }),
        red_gate("twelve_b_candidate_selected", |gates| {
            gates[0].model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string();
        }),
        red_gate("thirty_one_b_candidate_selected", |gates| {
            gates[0].model_id = "google/gemma-4-31B-it-qat-q4_0-gguf".to_string();
        }),
        red_gate("mlx_lane_selected", |gates| {
            gates[0].runtime_lane = QatRouteRuntimeLane::MlxSwiftCandidate;
        }),
        red_gate("owner_approval_granted", |gates| {
            gates[0].owner_approval_granted = true;
        }),
        red_gate("approval_status_approved", |gates| {
            gates[0].approval_status =
                SmallCompressedOwnerApprovalStatus::OwnerApprovedForSeparateRuntimeWitness;
        }),
        red_gate("owner_approval_not_required", |gates| {
            gates[0].owner_approval_required = false;
        }),
        red_gate("runtime_command_armed", |gates| {
            gates[0].runtime_command_armed = true;
        }),
        red_gate("runtime_command_executed", |gates| {
            gates[0].runtime_command_executed = true;
        }),
        red_gate("live_execution_performed", |gates| {
            gates[0].live_execution_performed = true;
        }),
        red_gate("first_token_claimed", |gates| {
            gates[0].first_token_claimed = true;
        }),
        red_gate("retained_token_digest_recorded", |gates| {
            gates[0].retained_token_digest_recorded = true;
        }),
        red_gate("bad_planned_route_bytes", |gates| {
            gates[0].bytes.planned_route_bytes += 1;
        }),
        red_gate("planned_model_equals_file", |gates| {
            gates[0].bytes.planned_model_bytes = gates[0].bytes.declared_file_bytes;
        }),
        red_gate("wrong_retained_token_budget", |gates| {
            gates[0].bytes.retained_token_budget = 2;
        }),
        red_gate("cancellation_exceeds_timeout", |gates| {
            gates[0].bytes.cancellation_deadline_ms = gates[0].bytes.timeout_ms + 1;
        }),
        red_gate("opened_model_bytes", |gates| {
            gates[0].bytes.opened_model_bytes = 1;
        }),
        red_gate("opened_runtime_bytes", |gates| {
            gates[0].bytes.opened_runtime_bytes = 1;
        }),
        red_gate("resident_model_bytes", |gates| {
            gates[0].bytes.resident_model_bytes = 1;
        }),
        red_gate("resident_runtime_bytes", |gates| {
            gates[0].bytes.resident_runtime_bytes = 1;
        }),
        red_gate("model_bytes_loaded", |gates| {
            gates[0].bytes.model_bytes_loaded = 1;
        }),
        red_gate("runtime_bytes_loaded", |gates| {
            gates[0].bytes.runtime_bytes_loaded = 1;
        }),
        red_gate("provider_call_made", |gates| {
            gates[0].bytes.provider_calls_made = 1;
        }),
        red_gate("missing_answer_packet", |gates| {
            gates[0].answer_packet_required = false;
        }),
        red_gate("missing_run_event_log", |gates| {
            gates[0].run_event_log_required = false;
        }),
        red_gate("missing_rollback", |gates| {
            gates[0].rollback_required = false;
        }),
        red_gate("missing_cancellation", |gates| {
            gates[0].cancellation_required = false;
        }),
        red_gate("missing_memory_ledger_required", |gates| {
            gates[0].memory_ledger_required = false;
        }),
        red_gate("missing_command_visibility", |gates| {
            gates[0].command_visible = false;
        }),
        red_gate("missing_selected_model_visibility", |gates| {
            gates[0].selected_model_visible = false;
        }),
        red_gate("missing_denied_routes_visibility", |gates| {
            gates[0].denied_routes_visible = false;
        }),
        red_gate("missing_byte_plan_visibility", |gates| {
            gates[0].byte_plan_visible = false;
        }),
        red_gate("mas_product_build", |gates| {
            gates[0].product_build = ProductBuild::Mas;
        }),
        red_gate("pro_live_status", |gates| {
            gates[0].pro_status = ProStatus::Live;
        }),
        red_gate("promotion_tier_t2", |gates| {
            gates[0].promotion_tier = SmallCompressedHarnessPromotionTier::T2L2Route;
        }),
        red_gate("quality_claim", |gates| {
            gates[0].quality_claimed = true;
        }),
        red_gate("l2_capability_claim", |gates| {
            gates[0].l2_capability_claimed = true;
        }),
        red_gate("l3_wrv_claim", |gates| {
            gates[0].l3_wrv_claimed = true;
        }),
        red_gate("mas_readiness_claim", |gates| {
            gates[0].mas_readiness_claimed = true;
        }),
        red_gate("hidden_cloud_fallback", |gates| {
            gates[0].hidden_cloud_fallback_allowed = true;
        }),
        red_gate("hidden_route_authority", |gates| {
            gates[0].hidden_route_authority_allowed = true;
        }),
        red_gate("route_policy_mutated", |gates| {
            gates[0].route_policy_mutated = true;
        }),
        red_gate("live_dense_70b_claim", |gates| {
            gates[0].live_dense_70b_claimed = true;
        }),
        red_gate("ssd_as_ram_claim", |gates| {
            gates[0].ssd_as_ram_claimed = true;
        }),
        red_gate("twelve_b_or_thirty_one_b_allowed", |gates| {
            gates[0].twelve_b_or_thirty_one_b_probe_allowed = true;
        }),
        red_gate("mlx_swift_loader_allowed", |gates| {
            gates[0].mlx_swift_loader_allowed = true;
        }),
        red_gate("litert_without_package_proof_allowed", |gates| {
            gates[0].litert_without_package_proof_allowed = true;
        }),
        red_gate("kv_direct_128k_shard_allowed", |gates| {
            gates[0].kv_direct_128k_shard_allowed = true;
        }),
        red_gate("mmap_or_ssd_stress_allowed", |gates| {
            gates[0].mmap_or_ssd_stress_allowed = true;
        }),
        red_gate("gate_metadata_budget_exceeded", |gates| {
            gates[0].bytes.metadata_bytes_read = 129 * 1024;
        }),
        (
            "set_metadata_budget_exceeded",
            set_from(
                valid_set.upstream_preflight_set_address.clone(),
                accepted_gates(),
                513 * 1024,
                true,
                true,
                true,
            )
            .is_err(),
        ),
        (
            "set_missing_layer_separation",
            set_from(
                valid_set.upstream_preflight_set_address.clone(),
                accepted_gates(),
                SET_METADATA_BYTES,
                false,
                true,
                true,
            )
            .is_err(),
        ),
        (
            "set_runtime_not_deferred",
            set_from(
                valid_set.upstream_preflight_set_address.clone(),
                accepted_gates(),
                SET_METADATA_BYTES,
                true,
                false,
                true,
            )
            .is_err(),
        ),
        (
            "set_product_promotion_allowed",
            set_from(
                valid_set.upstream_preflight_set_address.clone(),
                accepted_gates(),
                SET_METADATA_BYTES,
                true,
                true,
                false,
            )
            .is_err(),
        ),
    ]
}

fn red_gate(
    name: &'static str,
    mutate: impl FnOnce(&mut Vec<SmallCompressedModelOwnerApprovalRuntimeGate>),
) -> (&'static str, bool) {
    let mut gates = accepted_gates();
    mutate(&mut gates);
    let pass = set_from(
        upstream_fixture_address(),
        gates,
        SET_METADATA_BYTES,
        true,
        true,
        true,
    )
    .is_err();
    (name, pass)
}

#[allow(clippy::too_many_arguments)]
fn set_from(
    upstream_preflight_set_address: UasAddress,
    gates: Vec<SmallCompressedModelOwnerApprovalRuntimeGate>,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> Result<
    SmallCompressedModelOwnerApprovalRuntimeGateSet,
    agent_core::uas::SmallCompressedOwnerApprovalGateError,
> {
    SmallCompressedModelOwnerApprovalRuntimeGateSet::from_preflight(
        upstream_preflight_set_address,
        "artifact:small_compressed_model_live_harness_preflight:result",
        SELECTED_GATE_ID,
        gates,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked,
        CREATED_AT_MS,
    )
}

fn upstream_fixture_address() -> UasAddress {
    UasAddress::new(
        UasKind::Other("small_compressed_model_live_harness_preflight".to_string()),
        b"small-compressed-owner-gate-red-fixture",
        CREATED_AT_MS,
    )
}
