//! `falsify_gemma_direct_harness_trap_policy_gate`
//!
//! Metadata-only trap-policy gate for the first future owner-approved Gemma
//! direct-file runtime proof. It reads only the upstream command-card artifact,
//! opens no model files, arms no command, starts no server, uses no network or
//! cache path, and promotes no route.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaDirectHarnessTrapPolicyGate, GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_ID,
    GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_NEXT_CURSOR,
    GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_ID;
const FIXTURE_ID: &str = "gemma_direct_harness_trap_policy_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_direct_harness_trap_policy_gate.sh";
const RESULT: &str = "artifacts/falsifiers/gemma_direct_harness_trap_policy_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_proof_command_card/result.json";
const CREATED_AT_MS: u64 = 1_779_840_000_000;

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
        "{FALSIFIER_ID}: overall_pass={} denied_shapes={} denied_file_classes={} command_executed={} server_started={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["denied_runtime_shape_count"].value,
        artifact.measurements["denied_file_class_count"].value,
        artifact.measurements["command_executed_count"].value,
        artifact.measurements["server_started_count"].value,
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
    let upstream_pass = upstream_gate_pass(UPSTREAM_RESULT)?;
    let gate = GemmaDirectHarnessTrapPolicyGate::canonical();
    gate.validate()?;
    let reordered = GemmaDirectHarnessTrapPolicyGate {
        required_policy_fields: gate.required_policy_fields.iter().cloned().rev().collect(),
        allowed_runtime_shapes: gate.allowed_runtime_shapes.iter().cloned().rev().collect(),
        denied_runtime_shapes: gate.denied_runtime_shapes.iter().cloned().rev().collect(),
        denied_file_classes: gate.denied_file_classes.iter().cloned().rev().collect(),
        ..gate.clone()
    };
    reordered.validate()?;

    let metrics = gate.metrics();
    let red_results = red_fixture_results(&gate);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_command_card_gate_pass", upstream_pass),
        (
            "upstream_command_card_ref_bound",
            gate.upstream_command_card_ref == GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_UPSTREAM_REF,
        ),
        (
            "local_text_only_direct_file_offline_policy_bound",
            gate.text_only_required
                && gate.direct_local_file_required
                && gate.offline_required
                && red_pass(&red_results, "text_only_disabled")
                && red_pass(&red_results, "direct_file_disabled")
                && red_pass(&red_results, "offline_disabled"),
        ),
        (
            "required_policy_fields_bound",
            metrics.required_policy_field_count == 29
                && red_pass(&red_results, "missing_policy_field")
                && red_pass(&red_results, "duplicate_policy_field"),
        ),
        (
            "allowed_runtime_shapes_bound",
            metrics.allowed_runtime_shape_count == 14
                && red_pass(&red_results, "missing_allowed_shape")
                && red_pass(&red_results, "duplicate_allowed_shape"),
        ),
        (
            "denied_runtime_shapes_bound",
            metrics.denied_runtime_shape_count == 29
                && red_pass(&red_results, "missing_denied_shape")
                && red_pass(&red_results, "duplicate_denied_shape"),
        ),
        (
            "denied_file_classes_bound",
            metrics.denied_file_class_count == 8
                && red_pass(&red_results, "missing_denied_file_class")
                && red_pass(&red_results, "duplicate_denied_file_class"),
        ),
        (
            "server_network_hf_cache_provider_denied",
            gate.no_server_required
                && gate.no_network_required
                && gate.no_hf_cache_required
                && metrics.server_started_count == 0
                && metrics.network_hub_provider_count == 0
                && red_pass(&red_results, "server_started")
                && red_pass(&red_results, "network_allowed")
                && red_pass(&red_results, "hub_cache_allowed")
                && red_pass(&red_results, "provider_route_allowed"),
        ),
        (
            "mtp_mmproj_mlx_litert_substitution_denied",
            gate.no_mtp_drafter_required
                && gate.no_mmproj_required
                && gate.no_mlx_loader_assumption
                && gate.no_litert_assumption
                && metrics.file_open_count == 0
                && red_pass(&red_results, "mtp_policy_disabled")
                && red_pass(&red_results, "mmproj_policy_disabled")
                && red_pass(&red_results, "mlx_loader_assumption")
                && red_pass(&red_results, "litert_assumption")
                && red_pass(&red_results, "mmproj_opened")
                && red_pass(&red_results, "mlx_folder_opened")
                && red_pass(&red_results, "litert_bundle_opened"),
        ),
        (
            "rollback_log_packet_abstention_bound",
            gate.rollback_required
                && gate.run_event_log_required
                && gate.answer_packet_required
                && gate.abstention_required
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "zero_command_process_model_runtime_provider_actions",
            metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.process_spawned_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "process_spawned")
                && red_pass(&red_results, "model_file_opened")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "privacy_raw_path_prompt_output_denied",
            metrics.raw_private_bytes == 0
                && red_pass(&red_results, "raw_path_bytes")
                && red_pass(&red_results, "raw_prompt_bytes")
                && red_pass(&red_results, "raw_output_bytes"),
        ),
        (
            "no_route_system_g_settings_mutation",
            metrics.mutation_count == 0
                && red_pass(&red_results, "runtime_router_mutation")
                && red_pass(&red_results, "system_g_mutation")
                && red_pass(&red_results, "settings_default_mutation"),
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
            "no_quality_l2_l3_t4_default_70b_or_ssd_claim",
            metrics.promotion_claim_count == 0
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "l2_l3_t4_claim")
                && red_pass(&red_results, "gemma_default_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "gemma_direct_harness_trap_policy_address_deterministic",
            gate.policy_address(CREATED_AT_MS) == reordered.policy_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_NEXT_CURSOR
                == "gemma_direct_harness_first_runtime_proof_receipt_gate",
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
            "required_policy_field_count",
            metrics.required_policy_field_count,
            "==",
            29,
            "fields",
        ),
        (
            "allowed_runtime_shape_count",
            metrics.allowed_runtime_shape_count,
            "==",
            14,
            "shapes",
        ),
        (
            "denied_runtime_shape_count",
            metrics.denied_runtime_shape_count,
            "==",
            29,
            "shapes",
        ),
        (
            "denied_file_class_count",
            metrics.denied_file_class_count,
            "==",
            8,
            "classes",
        ),
        (
            "command_armed_count",
            metrics.command_armed_count,
            "==",
            0,
            "count",
        ),
        (
            "command_executed_count",
            metrics.command_executed_count,
            "==",
            0,
            "count",
        ),
        (
            "process_spawned_count",
            metrics.process_spawned_count,
            "==",
            0,
            "count",
        ),
        (
            "server_started_count",
            metrics.server_started_count,
            "==",
            0,
            "count",
        ),
        (
            "network_hub_provider_count",
            metrics.network_hub_provider_count,
            "==",
            0,
            "count",
        ),
        ("file_open_count", metrics.file_open_count, "==", 0, "count"),
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
            "count",
        ),
        (
            "raw_private_bytes",
            metrics.raw_private_bytes,
            "==",
            0,
            "bytes",
        ),
        ("mutation_count", metrics.mutation_count, "==", 0, "count"),
        (
            "hidden_authority_count",
            metrics.hidden_authority_count,
            "==",
            0,
            "count",
        ),
        (
            "promotion_claim_count",
            metrics.promotion_claim_count,
            "==",
            0,
            "count",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            ">=",
            48,
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
        "gemma_direct_harness_trap_policy_address",
        &gate.policy_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_NEXT_CURSOR,
        "gemma_direct_harness_first_runtime_proof_receipt_gate",
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
        notes: "metadata-only F-GemmaDirectHarnessTrapPolicyGate: consumes the Gemma direct-harness first-runtime command card and freezes a fail-closed trap policy before any owner-approved execution. It allows only text-only direct local GGUF llama-cli --offline -m proof shape and denies -hf/HF cache, llama-server, network/provider endpoints, MTP/drafter, mmproj/multimodal, MLX folder, LiteRT bundle, safetensors, unbounded context/predict, route/default mutation, hidden authority, live Gemma/default/L2/L3/T4, live dense 70B, and SSD-as-RAM claims. It opens zero files, arms/runs zero commands, spawns zero processes, starts zero servers, loads zero model/runtime/provider bytes, captures zero raw private bytes, and promotes no product route.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_gate_pass(path: &str) -> Result<bool, Box<dyn std::error::Error>> {
    if !Path::new(path).exists() {
        return Ok(false);
    }
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(path)?)?;
    Ok(value
        .get("overall_pass")
        .and_then(|value| value.as_bool())
        .unwrap_or(false))
}

fn red_fixture_results(gate: &GemmaDirectHarnessTrapPolicyGate) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaDirectHarnessTrapPolicyGate)>,
    )> = vec![
        (
            "bad_upstream_ref",
            Box::new(|g| {
                g.upstream_command_card_ref =
                    "artifact:falsifiers/wrong/result.json#wrong".to_string()
            }),
        ),
        (
            "bad_upstream_id",
            Box::new(|g| g.upstream_command_card_id = "F-Wrong".to_string()),
        ),
        (
            "bad_artifact_root",
            Box::new(|g| g.artifact_root_prefix = "artifacts/falsifiers/wrong/".to_string()),
        ),
        (
            "bad_policy_id",
            Box::new(|g| g.policy_id = "wrong".to_string()),
        ),
        (
            "bad_runtime_lane",
            Box::new(|g| g.runtime_lane = "gemma-server".to_string()),
        ),
        (
            "missing_policy_field",
            Box::new(|g| {
                g.required_policy_fields.pop();
            }),
        ),
        (
            "duplicate_policy_field",
            Box::new(|g| g.required_policy_fields[0] = g.required_policy_fields[1].clone()),
        ),
        (
            "missing_allowed_shape",
            Box::new(|g| {
                g.allowed_runtime_shapes.pop();
            }),
        ),
        (
            "duplicate_allowed_shape",
            Box::new(|g| g.allowed_runtime_shapes[0] = g.allowed_runtime_shapes[1].clone()),
        ),
        (
            "missing_denied_shape",
            Box::new(|g| {
                g.denied_runtime_shapes.pop();
            }),
        ),
        (
            "duplicate_denied_shape",
            Box::new(|g| g.denied_runtime_shapes[0] = g.denied_runtime_shapes[1].clone()),
        ),
        (
            "missing_denied_file_class",
            Box::new(|g| {
                g.denied_file_classes.pop();
            }),
        ),
        (
            "duplicate_denied_file_class",
            Box::new(|g| g.denied_file_classes[0] = g.denied_file_classes[1].clone()),
        ),
        (
            "text_only_disabled",
            Box::new(|g| g.text_only_required = false),
        ),
        (
            "direct_file_disabled",
            Box::new(|g| g.direct_local_file_required = false),
        ),
        ("offline_disabled", Box::new(|g| g.offline_required = false)),
        (
            "server_policy_disabled",
            Box::new(|g| g.no_server_required = false),
        ),
        (
            "network_policy_disabled",
            Box::new(|g| g.no_network_required = false),
        ),
        (
            "hf_cache_policy_disabled",
            Box::new(|g| g.no_hf_cache_required = false),
        ),
        (
            "mtp_policy_disabled",
            Box::new(|g| g.no_mtp_drafter_required = false),
        ),
        (
            "mmproj_policy_disabled",
            Box::new(|g| g.no_mmproj_required = false),
        ),
        (
            "mlx_loader_assumption",
            Box::new(|g| g.no_mlx_loader_assumption = false),
        ),
        (
            "litert_assumption",
            Box::new(|g| g.no_litert_assumption = false),
        ),
        (
            "rollback_missing",
            Box::new(|g| g.rollback_required = false),
        ),
        (
            "run_event_log_missing",
            Box::new(|g| g.run_event_log_required = false),
        ),
        (
            "answer_packet_missing",
            Box::new(|g| g.answer_packet_required = false),
        ),
        (
            "abstention_missing",
            Box::new(|g| g.abstention_required = false),
        ),
        ("command_armed", Box::new(|g| g.command_armed = true)),
        ("command_executed", Box::new(|g| g.command_executed = true)),
        ("process_spawned", Box::new(|g| g.process_spawned = true)),
        ("server_started", Box::new(|g| g.server_started = true)),
        ("network_allowed", Box::new(|g| g.network_allowed = true)),
        (
            "hub_cache_allowed",
            Box::new(|g| g.hub_cache_allowed = true),
        ),
        (
            "provider_route_allowed",
            Box::new(|g| g.provider_route_allowed = true),
        ),
        (
            "model_file_opened",
            Box::new(|g| g.model_file_opened = true),
        ),
        ("mmproj_opened", Box::new(|g| g.mmproj_opened = true)),
        (
            "mlx_folder_opened",
            Box::new(|g| g.mlx_folder_opened = true),
        ),
        (
            "litert_bundle_opened",
            Box::new(|g| g.litert_bundle_opened = true),
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
        ("raw_path_bytes", Box::new(|g| g.raw_path_bytes = 1)),
        ("raw_prompt_bytes", Box::new(|g| g.raw_prompt_bytes = 1)),
        ("raw_output_bytes", Box::new(|g| g.raw_output_bytes = 1)),
        (
            "runtime_router_mutation",
            Box::new(|g| g.runtime_router_mutation_allowed = true),
        ),
        (
            "system_g_mutation",
            Box::new(|g| g.system_g_mutation_allowed = true),
        ),
        (
            "settings_default_mutation",
            Box::new(|g| g.settings_or_default_mutation_allowed = true),
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
        ("quality_claim", Box::new(|g| g.quality_claimed = true)),
        (
            "l2_l3_t4_claim",
            Box::new(|g| {
                g.l2_capability_effect = true;
                g.l3_wrv_effect = true;
                g.t4_build_green_effect = true;
            }),
        ),
        (
            "gemma_default_claim",
            Box::new(|g| g.live_gemma_default_claim = true),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|g| g.live_dense_70b_claim = true),
        ),
        ("ssd_as_ram_claim", Box::new(|g| g.ssd_as_ram_claim = true)),
        (
            "metadata_over_budget",
            Box::new(|g| g.metadata_bytes = 999_999),
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
    for axis in GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
