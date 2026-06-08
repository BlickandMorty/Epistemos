//! `falsify_gemma_qat_e2b_product_capability_recheck_gate`
//!
//! Metadata-only product capability recheck for Gemma E2B. The expected current
//! result is blocked because the release-audit automated-check bottleneck is
//! still red.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaQatE2bProductCapabilityRecheckGate, GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
    GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_ID,
    GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_NEXT_CURSOR,
    GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_ID;
const FIXTURE_ID: &str = "gemma_qat_e2b_product_capability_recheck_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_e2b_product_capability_recheck_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_product_capability_recheck_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_release_audit_surface_gate/result.json";
const GUARD_RESULT: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const KERNEL_RESULT: &str = "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const PRODUCT_BLOCKER_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";
const ROUTE_STATUS_BLOCKED: &str = "vault_research_route_with_packetized_mitigation";
const CREATED_AT_MS: u64 = 1_779_582_000_000;

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
        "{FALSIFIER_ID}: overall_pass={} recheck_fields={} blocked_truth_count={} action_leak_count={} model_bytes_loaded={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_recheck_field_count"].value,
        artifact.measurements["blocked_truth_count"].value,
        artifact.measurements["action_leak_count"].value,
        artifact.measurements["model_bytes_loaded"].value,
        artifact.measurements["red_fixture_rejection_count"].value,
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let upstream_pass = json_overall_pass(UPSTREAM_RESULT)?;
    let guard_cursor_match = json_measurement_string(GUARD_RESULT, "next_existing_work")?
        .as_deref()
        == Some(PRODUCT_BLOCKER_CURSOR);
    let kernel_red = json_overall_pass(KERNEL_RESULT)? == false;
    let kernel_bottleneck_match = json_measurement_string(KERNEL_RESULT, "next_bottleneck")?
        .as_deref()
        == Some(PRODUCT_BLOCKER_CURSOR);
    let kernel_route_status_match = json_measurement_string(KERNEL_RESULT, "route_status")?
        .as_deref()
        == Some(ROUTE_STATUS_BLOCKED);

    let gate = GemmaQatE2bProductCapabilityRecheckGate::canonical(
        GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_UPSTREAM_REF,
    );
    gate.validate()?;
    let reversed = GemmaQatE2bProductCapabilityRecheckGate {
        required_recheck_fields: gate.required_recheck_fields.iter().cloned().rev().collect(),
        required_rejection_policies: gate
            .required_rejection_policies
            .iter()
            .cloned()
            .rev()
            .collect(),
        ..gate.clone()
    };
    reversed.validate()?;

    let metrics = gate.metrics();
    let red_results = red_fixture_results(&gate);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_release_audit_surface_gate_pass", upstream_pass),
        (
            "upstream_release_audit_surface_ref_bound",
            gate.upstream_release_audit_surface_ref
                == GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_UPSTREAM_REF,
        ),
        (
            "single_e2b_gguf_llama_cpp_recheck_lane_bound",
            gate.selected_model_id == "google/gemma-4-E2B-it-qat-q4_0-gguf"
                && gate.required_filename == "gemma-4-E2B_q4_0-it.gguf"
                && gate.expected_file_size_bytes == GEMMA_QAT_E2B_EXPECTED_FILE_BYTES
                && red_pass(&red_results, "wrong_model")
                && red_pass(&red_results, "wrong_filename")
                && red_pass(&red_results, "wrong_expected_file_bytes")
                && red_pass(&red_results, "wrong_runtime_lane"),
        ),
        (
            "capability_kernel_red_status_bound",
            kernel_red
                && kernel_bottleneck_match
                && kernel_route_status_match
                && gate.capability_kernel_red_required
                && gate.expected_next_bottleneck == PRODUCT_BLOCKER_CURSOR
                && gate.expected_route_status == ROUTE_STATUS_BLOCKED
                && red_pass(&red_results, "capability_kernel_green")
                && red_pass(&red_results, "wrong_bottleneck")
                && red_pass(&red_results, "wrong_route_status"),
        ),
        (
            "guard_cursor_and_release_blocker_bound",
            guard_cursor_match
                && gate.guard_cursor_match_required
                && gate.automated_checks_blocker_required
                && gate.xcode_test_red_required
                && red_pass(&red_results, "guard_cursor_missing")
                && red_pass(&red_results, "automated_blocker_missing")
                && red_pass(&red_results, "xcode_test_not_red"),
        ),
        (
            "recheck_fields_and_rejection_policies_bound",
            metrics.required_recheck_field_count == 36
                && metrics.required_rejection_policy_count == 52
                && red_pass(&red_results, "missing_recheck_field")
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "pending_product_evidence_bound",
            metrics.blocked_truth_count == 9
                && gate.focused_proof_root_pending_required
                && gate.log_correlation_pending_required
                && gate.manual_runtime_pending_required
                && gate.distribution_compliance_pending_required
                && gate.repeated_zero_fail_pending_required
                && red_pass(&red_results, "focused_proof_done")
                && red_pass(&red_results, "log_correlation_done")
                && red_pass(&red_results, "manual_runtime_done")
                && red_pass(&red_results, "distribution_done")
                && red_pass(&red_results, "zero_fail_done"),
        ),
        (
            "gated_surfaces_and_owner_action_bound",
            metrics.gated_surface_count == 6
                && gate.settings_row_gated_only
                && gate.diagnostics_row_gated_only
                && gate.runtime_route_blocked
                && gate.default_model_blocked
                && gate.answer_packet_user_surface_blocked
                && gate.owner_action_required
                && red_pass(&red_results, "settings_unlocked")
                && red_pass(&red_results, "diagnostics_unlocked")
                && red_pass(&red_results, "runtime_route_unblocked")
                && red_pass(&red_results, "default_model_unblocked")
                && red_pass(&red_results, "answer_packet_unblocked")
                && red_pass(&red_results, "owner_action_missing"),
        ),
        (
            "proof_surfaces_required",
            gate.run_event_log_required
                && gate.rollback_required
                && gate.abstention_required
                && gate.scope_rex_required
                && gate.sovereign_gate_required
                && gate.cancellation_required
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "abstention_missing")
                && red_pass(&red_results, "scope_rex_missing")
                && red_pass(&red_results, "sovereign_gate_missing")
                && red_pass(&red_results, "cancellation_missing"),
        ),
        (
            "zero_recheck_xcode_model_runtime_provider_actions",
            metrics.action_leak_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "recheck_green")
                && red_pass(&red_results, "xcode_executed")
                && red_pass(&red_results, "model_command_armed")
                && red_pass(&red_results, "model_command_executed")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "privacy_preserved",
            metrics.raw_prompt_bytes_captured == 0
                && metrics.raw_output_bytes_captured == 0
                && red_pass(&red_results, "raw_prompt_captured")
                && red_pass(&red_results, "raw_output_captured"),
        ),
        (
            "no_hidden_authority_or_cloud_fallback",
            metrics.hidden_authority_count == 0
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_eidos_authority")
                && red_pass(&red_results, "hidden_lattice_authority")
                && red_pass(&red_results, "hidden_patternboost_authority")
                && red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "no_mas_l2_l3_t4_product_gemma_default_quality_or_large_model_claim",
            metrics.promotion_claim_count == 0
                && red_pass(&red_results, "mas_promotion")
                && red_pass(&red_results, "l2_promotion")
                && red_pass(&red_results, "l3_promotion")
                && red_pass(&red_results, "t4_promotion")
                && red_pass(&red_results, "product_route_green")
                && red_pass(&red_results, "gemma_default_claim")
                && red_pass(&red_results, "larger_model_bypass")
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "benchmark_fit_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "gemma_e2b_product_capability_recheck_gate_address_deterministic",
            gate.recheck_address(CREATED_AT_MS) == reversed.recheck_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_NEXT_CURSOR
                == "gemma_qat_e2b_release_audit_blocker_repair_bridge_gate",
        ),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }

    for (name, value, operator, expected, unit) in [
        (
            "required_recheck_field_count",
            metrics.required_recheck_field_count,
            "==",
            36,
            "fields",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            52,
            "policies",
        ),
        (
            "blocked_truth_count",
            metrics.blocked_truth_count,
            "==",
            9,
            "blocked_truths",
        ),
        (
            "gated_surface_count",
            metrics.gated_surface_count,
            "==",
            6,
            "surfaces",
        ),
        (
            "action_leak_count",
            metrics.action_leak_count,
            "==",
            0,
            "actions",
        ),
        (
            "model_bytes_loaded",
            metrics.model_bytes_loaded,
            "==",
            0,
            "bytes",
        ),
        (
            "runtime_bytes_loaded",
            metrics.runtime_bytes_loaded,
            "==",
            0,
            "bytes",
        ),
        (
            "provider_calls_made",
            metrics.provider_calls_made,
            "==",
            0,
            "calls",
        ),
        (
            "raw_prompt_bytes_captured",
            metrics.raw_prompt_bytes_captured,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_output_bytes_captured",
            metrics.raw_output_bytes_captured,
            "==",
            0,
            "bytes",
        ),
        (
            "hidden_authority_count",
            metrics.hidden_authority_count,
            "==",
            0,
            "claims",
        ),
        (
            "promotion_claim_count",
            metrics.promotion_claim_count,
            "==",
            0,
            "claims",
        ),
        (
            "expected_file_size_bytes",
            gate.expected_file_size_bytes,
            "==",
            GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
            "bytes",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            ">=",
            55,
            "fixtures",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            value,
            operator,
            expected,
            unit,
        );
    }

    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "gemma_e2b_product_capability_recheck_gate_address",
        &gate.recheck_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_NEXT_CURSOR,
        "gemma_qat_e2b_release_audit_blocker_repair_bridge_gate",
    );

    assert_axis_coverage(&measurements);

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
        notes: "metadata-only F-GemmaQATE2BProductCapabilityRecheckGate: consumes the E2B release-audit surface gate and rechecks product truth against the current red capability kernel. It passes only when the Gemma E2B product route remains blocked by the release-audit automated-check bottleneck, with focused proof-root, log correlation, manual runtime, distribution/compliance, and repeated-zero-fail evidence still pending. It runs no Xcode command, wires no settings or diagnostics product surface, emits no user AnswerPacket, arms or executes no model command, loads zero model/runtime/provider bytes, captures zero raw prompt/output bytes, and makes no MAS/L2/L3/T4/user-facing, Gemma-default, quality, benchmark-fit, E4B/12B/70B bypass, live-70B, or SSD-as-RAM claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn json_overall_pass(path: &str) -> Result<bool, Box<dyn std::error::Error>> {
    if !Path::new(path).exists() {
        return Ok(false);
    }
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(path)?)?;
    Ok(value
        .get("overall_pass")
        .and_then(|value| value.as_bool())
        .unwrap_or(false))
}

fn json_measurement_string(
    path: &str,
    measurement: &str,
) -> Result<Option<String>, Box<dyn std::error::Error>> {
    if !Path::new(path).exists() {
        return Ok(None);
    }
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(path)?)?;
    Ok(value
        .get("measurements")
        .and_then(|measurements| measurements.get(measurement))
        .and_then(|entry| entry.get("value"))
        .and_then(|value| value.as_str())
        .map(ToOwned::to_owned))
}

fn red_fixture_results(
    gate: &GemmaQatE2bProductCapabilityRecheckGate,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaQatE2bProductCapabilityRecheckGate)>,
    )> = vec![
        (
            "wrong_model",
            Box::new(|g| g.selected_model_id = "google/gemma-4-E4B-it-qat-q4_0-gguf".to_string()),
        ),
        (
            "wrong_filename",
            Box::new(|g| g.required_filename = "gemma-4-E4B_q4_0-it.gguf".to_string()),
        ),
        (
            "wrong_expected_file_bytes",
            Box::new(|g| g.expected_file_size_bytes += 1),
        ),
        (
            "wrong_runtime_lane",
            Box::new(|g| g.runtime_lane = agent_core::uas::GemmaFamilyRuntimeLane::LiteRtLm),
        ),
        (
            "bad_upstream_ref",
            Box::new(|g| g.upstream_release_audit_surface_ref = "artifact:wrong".to_string()),
        ),
        (
            "bad_upstream_id",
            Box::new(|g| g.upstream_release_audit_surface_id = "F-Wrong".to_string()),
        ),
        (
            "bad_artifact_root",
            Box::new(|g| g.artifact_root_prefix = "artifacts/falsifiers/wrong/".to_string()),
        ),
        (
            "bad_recheck_card",
            Box::new(|g| g.recheck_card_id = "wrong".to_string()),
        ),
        (
            "capability_kernel_green",
            Box::new(|g| g.capability_kernel_red_required = false),
        ),
        (
            "wrong_bottleneck",
            Box::new(|g| g.expected_next_bottleneck = "wrong".to_string()),
        ),
        (
            "wrong_route_status",
            Box::new(|g| g.expected_route_status = "live".to_string()),
        ),
        (
            "guard_cursor_missing",
            Box::new(|g| g.guard_cursor_match_required = false),
        ),
        (
            "automated_blocker_missing",
            Box::new(|g| g.automated_checks_blocker_required = false),
        ),
        (
            "xcode_test_not_red",
            Box::new(|g| g.xcode_test_red_required = false),
        ),
        (
            "missing_recheck_field",
            Box::new(|g| {
                g.required_recheck_fields.pop();
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|g| {
                g.required_rejection_policies.pop();
            }),
        ),
        (
            "focused_proof_done",
            Box::new(|g| g.focused_proof_root_pending_required = false),
        ),
        (
            "log_correlation_done",
            Box::new(|g| g.log_correlation_pending_required = false),
        ),
        (
            "manual_runtime_done",
            Box::new(|g| g.manual_runtime_pending_required = false),
        ),
        (
            "distribution_done",
            Box::new(|g| g.distribution_compliance_pending_required = false),
        ),
        (
            "zero_fail_done",
            Box::new(|g| g.repeated_zero_fail_pending_required = false),
        ),
        (
            "settings_unlocked",
            Box::new(|g| g.settings_row_gated_only = false),
        ),
        (
            "diagnostics_unlocked",
            Box::new(|g| g.diagnostics_row_gated_only = false),
        ),
        (
            "runtime_route_unblocked",
            Box::new(|g| g.runtime_route_blocked = false),
        ),
        (
            "default_model_unblocked",
            Box::new(|g| g.default_model_blocked = false),
        ),
        (
            "answer_packet_unblocked",
            Box::new(|g| g.answer_packet_user_surface_blocked = false),
        ),
        (
            "owner_action_missing",
            Box::new(|g| g.owner_action_required = false),
        ),
        (
            "run_event_log_missing",
            Box::new(|g| g.run_event_log_required = false),
        ),
        (
            "rollback_missing",
            Box::new(|g| g.rollback_required = false),
        ),
        (
            "abstention_missing",
            Box::new(|g| g.abstention_required = false),
        ),
        (
            "scope_rex_missing",
            Box::new(|g| g.scope_rex_required = false),
        ),
        (
            "sovereign_gate_missing",
            Box::new(|g| g.sovereign_gate_required = false),
        ),
        (
            "cancellation_missing",
            Box::new(|g| g.cancellation_required = false),
        ),
        (
            "recheck_green",
            Box::new(|g| g.product_capability_recheck_green = true),
        ),
        ("xcode_executed", Box::new(|g| g.xcode_executed = true)),
        (
            "model_command_armed",
            Box::new(|g| g.model_command_armed = true),
        ),
        (
            "model_command_executed",
            Box::new(|g| g.model_command_executed = true),
        ),
        ("model_bytes_loaded", Box::new(|g| g.model_bytes_loaded = 1)),
        (
            "runtime_bytes_loaded",
            Box::new(|g| g.runtime_bytes_loaded = 1),
        ),
        (
            "provider_calls_made",
            Box::new(|g| g.provider_calls_made = 1),
        ),
        (
            "raw_prompt_captured",
            Box::new(|g| g.raw_prompt_bytes_captured = 1),
        ),
        (
            "raw_output_captured",
            Box::new(|g| g.raw_output_bytes_captured = 1),
        ),
        (
            "hidden_route_authority",
            Box::new(|g| g.hidden_route_authority = true),
        ),
        (
            "hidden_eidos_authority",
            Box::new(|g| g.hidden_eidos_authority = true),
        ),
        (
            "hidden_lattice_authority",
            Box::new(|g| g.hidden_lattice_authority = true),
        ),
        (
            "hidden_patternboost_authority",
            Box::new(|g| g.hidden_patternboost_authority = true),
        ),
        (
            "hidden_cloud_fallback",
            Box::new(|g| g.hidden_cloud_fallback = true),
        ),
        ("mas_promotion", Box::new(|g| g.mas_promoted = true)),
        ("l2_promotion", Box::new(|g| g.l2_capability_effect = true)),
        ("l3_promotion", Box::new(|g| g.l3_wrv_effect = true)),
        ("t4_promotion", Box::new(|g| g.t4_build_green_effect = true)),
        (
            "product_route_green",
            Box::new(|g| g.product_route_green = true),
        ),
        (
            "gemma_default_claim",
            Box::new(|g| g.live_gemma_default_claim = true),
        ),
        (
            "larger_model_bypass",
            Box::new(|g| g.larger_model_bypass_allowed = true),
        ),
        ("quality_claim", Box::new(|g| g.quality_claimed = true)),
        (
            "benchmark_fit_claim",
            Box::new(|g| g.benchmark_claimed_as_fit = true),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|g| g.live_dense_70b_claim = true),
        ),
        ("ssd_as_ram_claim", Box::new(|g| g.ssd_as_ram_claim = true)),
        (
            "metadata_budget_overflow",
            Box::new(|g| g.metadata_bytes = 512 * 1024),
        ),
        (
            "wrong_product_build",
            Box::new(|g| g.product_build = agent_core::uas::ProductBuild::Mas),
        ),
        (
            "wrong_pro_status",
            Box::new(|g| g.pro_status = agent_core::uas::ProStatus::Live),
        ),
        (
            "wrong_next_cursor",
            Box::new(|g| g.next_cursor = "wrong_next".to_string()),
        ),
    ];
    cases
        .into_iter()
        .map(|(name, mutate)| {
            let mut mutated = gate.clone();
            mutate(&mut mutated);
            (name, mutated.validate().is_err())
        })
        .collect()
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(case, _)| *case == name)
        .map(|(_, passed)| *passed)
        .unwrap_or(false)
}

fn add_text_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
    expected: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "text".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::String(expected.to_string()),
            unit: "text".to_string(),
        },
    );
    pass_per_axis.insert(
        name.to_string(),
        if expected == "non_empty" {
            !value.trim().is_empty()
        } else {
            value == expected
        },
    );
}

fn assert_axis_coverage(measurements: &BTreeMap<String, Measurement>) {
    for axis in GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
