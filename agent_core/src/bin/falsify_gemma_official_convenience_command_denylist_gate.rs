//! `falsify_gemma_official_convenience_command_denylist_gate`
//!
//! Metadata-only denylist gate for official Gemma convenience commands. It
//! proves that official `-hf`, server, endpoint, and LiteRT-LM examples remain
//! source references until a local artifact receipt and direct local-file
//! runtime receipt exist.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaOfficialConvenienceCommandDenylistGate,
    GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_ID,
    GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_NEXT_CURSOR,
    GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_ID;
const FIXTURE_ID: &str = "gemma_official_convenience_command_denylist_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_official_convenience_command_denylist_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_official_convenience_command_denylist_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_local_artifact_acquisition_receipt_gate/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} denied_commands={} shortcut_promotions={} command_executed={} server_started={} model_bytes_loaded={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["denied_convenience_command_count"].value,
        artifact.measurements["shortcut_promotion_count"].value,
        artifact.measurements["command_executed_count"].value,
        artifact.measurements["server_started_count"].value,
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
    let upstream_pass = upstream_gate_pass(UPSTREAM_RESULT)?;
    let gate = GemmaOfficialConvenienceCommandDenylistGate::canonical();
    gate.validate()?;
    let metrics = gate.metrics();
    let red_results = red_fixture_results(&gate);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_acquisition_receipt_gate_pass", upstream_pass),
        (
            "upstream_acquisition_receipt_gate_ref_bound",
            gate.upstream_receipt_gate_ref
                == GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_UPSTREAM_REF,
        ),
        (
            "official_source_refs_bound",
            metrics.official_source_ref_count == 4
                && red_pass(&red_results, "missing_official_source_ref")
                && red_pass(&red_results, "duplicate_official_source_ref"),
        ),
        (
            "denied_convenience_commands_bound",
            metrics.denied_convenience_command_count == 8
                && red_pass(&red_results, "missing_denied_convenience_command")
                && red_pass(&red_results, "duplicate_denied_convenience_command"),
        ),
        (
            "replacement_proofs_bound",
            metrics.replacement_proof_count == 14
                && red_pass(&red_results, "missing_replacement_proof"),
        ),
        (
            "rejection_policies_bound",
            metrics.rejection_policy_count == 30
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "official_shortcuts_non_promotional",
            metrics.shortcut_promotion_count == 0
                && red_pass(&red_results, "official_card_as_runtime_proof")
                && red_pass(&red_results, "hf_command_as_receipt")
                && red_pass(&red_results, "server_as_route_admission")
                && red_pass(&red_results, "endpoint_as_system_g_admission")
                && red_pass(&red_results, "hf_cache_path_as_local_identity"),
        ),
        (
            "private_bytes_denied",
            metrics.private_bytes_allowed_count == 0
                && red_pass(&red_results, "raw_path_or_token_leak"),
        ),
        (
            "network_command_server_actions_zero",
            metrics.network_allowed_count == 0
                && metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.server_started_count == 0
                && red_pass(&red_results, "network_allowed")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "server_started"),
        ),
        (
            "zero_model_runtime_provider_bytes",
            metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_called"),
        ),
        (
            "no_route_system_g_settings_mutation",
            metrics.route_mutation_count == 0
                && red_pass(&red_results, "runtime_router_mutation")
                && red_pass(&red_results, "system_g_mutation")
                && red_pass(&red_results, "settings_default_mutation"),
        ),
        (
            "no_hidden_authority_or_cloud_fallback",
            metrics.hidden_authority_count == 0
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "rollback_log_packet_abstention_bound",
            gate.rollback_ref.starts_with("rollback:")
                && gate.run_event_log_ref.starts_with("run_event_log:")
                && gate.answer_packet_ref.starts_with("answer_packet:")
                && gate.abstention_required
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "no_l2_l3_t4_gemma_70b_or_ssd_claim",
            metrics.promotion_claim_count == 0
                && red_pass(&red_results, "l2_l3_t4_claim")
                && red_pass(&red_results, "live_gemma_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "gemma_official_convenience_command_denylist_gate_address_deterministic",
            gate.address() == GemmaOfficialConvenienceCommandDenylistGate::canonical().address(),
        ),
        (
            "next_cursor_bound",
            gate.next_cursor == GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_NEXT_CURSOR,
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
            "official_source_ref_count",
            metrics.official_source_ref_count,
            "==",
            4,
            "refs",
        ),
        (
            "denied_convenience_command_count",
            metrics.denied_convenience_command_count,
            "==",
            8,
            "commands",
        ),
        (
            "replacement_proof_count",
            metrics.replacement_proof_count,
            "==",
            14,
            "proofs",
        ),
        (
            "rejection_policy_count",
            metrics.rejection_policy_count,
            "==",
            30,
            "policies",
        ),
        (
            "shortcut_promotion_count",
            metrics.shortcut_promotion_count,
            "==",
            0,
            "shortcuts",
        ),
        (
            "private_bytes_allowed_count",
            metrics.private_bytes_allowed_count,
            "==",
            0,
            "leaks",
        ),
        (
            "network_allowed_count",
            metrics.network_allowed_count,
            "==",
            0,
            "networks",
        ),
        (
            "command_armed_count",
            metrics.command_armed_count,
            "==",
            0,
            "commands",
        ),
        (
            "command_executed_count",
            metrics.command_executed_count,
            "==",
            0,
            "commands",
        ),
        (
            "server_started_count",
            metrics.server_started_count,
            "==",
            0,
            "servers",
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
            "route_mutation_count",
            metrics.route_mutation_count,
            "==",
            0,
            "mutations",
        ),
        (
            "hidden_authority_count",
            metrics.hidden_authority_count,
            "==",
            0,
            "authorities",
        ),
        (
            "promotion_claim_count",
            metrics.promotion_claim_count,
            "==",
            0,
            "claims",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            ">=",
            red_results.len() as u64,
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
        "gemma_official_convenience_command_denylist_gate_address",
        &gate.address().to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_NEXT_CURSOR,
        GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_NEXT_CURSOR,
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
        notes: "metadata-only F-GemmaOfficialConvenienceCommandDenylistGate: consumes the Gemma acquisition receipt gate and proves official convenience commands remain source references, not acquisition receipts, route admission, or product capability. It arms zero commands, starts zero servers, performs zero network/provider calls, loads zero model/runtime bytes, mutates no RuntimeRouter/System G/settings/default state, and makes no Gemma L2/L3/T4/user-facing claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_gate_pass(path: &str) -> Result<bool, Box<dyn std::error::Error>> {
    let resolved = resolve_repo_path(path);
    if !resolved.exists() {
        return Ok(false);
    }
    let bytes = std::fs::read(resolved)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(json
        .get("overall_pass")
        .and_then(|value| value.as_bool())
        .unwrap_or(false))
}

fn resolve_repo_path(path: &str) -> PathBuf {
    let direct = PathBuf::from(path);
    if direct.exists() {
        return direct;
    }
    let mut current = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
    loop {
        let candidate = current.join(path);
        if candidate.exists() {
            return candidate;
        }
        if !current.pop() {
            break;
        }
    }
    direct
}

fn red_fixture_results(
    gate: &GemmaOfficialConvenienceCommandDenylistGate,
) -> Vec<(&'static str, bool)> {
    let mut fixtures: Vec<(
        &'static str,
        Box<
            dyn Fn(
                GemmaOfficialConvenienceCommandDenylistGate,
            ) -> GemmaOfficialConvenienceCommandDenylistGate,
        >,
    )> = vec![
        (
            "missing_official_source_ref",
            Box::new(|mut g| {
                g.official_source_refs.pop();
                g
            }),
        ),
        (
            "duplicate_official_source_ref",
            Box::new(|mut g| {
                g.official_source_refs
                    .push(g.official_source_refs[0].clone());
                g
            }),
        ),
        (
            "missing_denied_convenience_command",
            Box::new(|mut g| {
                g.denied_convenience_commands.pop();
                g
            }),
        ),
        (
            "duplicate_denied_convenience_command",
            Box::new(|mut g| {
                g.denied_convenience_commands
                    .push(g.denied_convenience_commands[0].clone());
                g
            }),
        ),
        (
            "missing_replacement_proof",
            Box::new(|mut g| {
                g.required_replacement_proofs.pop();
                g
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|mut g| {
                g.required_rejection_policies.pop();
                g
            }),
        ),
        (
            "official_card_as_runtime_proof",
            Box::new(|mut g| {
                g.official_card_counts_as_runtime_proof = true;
                g
            }),
        ),
        (
            "hf_command_as_receipt",
            Box::new(|mut g| {
                g.convenience_command_counts_as_receipt = true;
                g
            }),
        ),
        (
            "server_as_route_admission",
            Box::new(|mut g| {
                g.server_counts_as_route_admission = true;
                g
            }),
        ),
        (
            "endpoint_as_system_g_admission",
            Box::new(|mut g| {
                g.endpoint_counts_as_system_g_admission = true;
                g
            }),
        ),
        (
            "hf_cache_path_as_local_identity",
            Box::new(|mut g| {
                g.hf_cache_path_counts_as_local_identity = true;
                g
            }),
        ),
        (
            "raw_path_or_token_leak",
            Box::new(|mut g| {
                g.raw_path_or_token_bytes_allowed = true;
                g
            }),
        ),
        (
            "network_allowed",
            Box::new(|mut g| {
                g.network_allowed_for_runtime_probe = true;
                g
            }),
        ),
        (
            "command_armed",
            Box::new(|mut g| {
                g.command_armed = true;
                g
            }),
        ),
        (
            "command_executed",
            Box::new(|mut g| {
                g.command_executed = true;
                g
            }),
        ),
        (
            "server_started",
            Box::new(|mut g| {
                g.server_started = true;
                g
            }),
        ),
        (
            "model_bytes_loaded",
            Box::new(|mut g| {
                g.model_bytes_loaded = 1;
                g
            }),
        ),
        (
            "runtime_bytes_loaded",
            Box::new(|mut g| {
                g.runtime_bytes_loaded = 1;
                g
            }),
        ),
        (
            "provider_called",
            Box::new(|mut g| {
                g.provider_calls_made = 1;
                g
            }),
        ),
        (
            "runtime_router_mutation",
            Box::new(|mut g| {
                g.runtime_router_mutation_allowed = true;
                g
            }),
        ),
        (
            "system_g_mutation",
            Box::new(|mut g| {
                g.system_g_mutation_allowed = true;
                g
            }),
        ),
        (
            "settings_default_mutation",
            Box::new(|mut g| {
                g.settings_default_mutation_allowed = true;
                g
            }),
        ),
        (
            "hidden_route_authority",
            Box::new(|mut g| {
                g.hidden_route_authority = true;
                g
            }),
        ),
        (
            "hidden_cloud_fallback",
            Box::new(|mut g| {
                g.hidden_cloud_fallback = true;
                g
            }),
        ),
        (
            "rollback_missing",
            Box::new(|mut g| {
                g.rollback_ref = "missing".to_string();
                g
            }),
        ),
        (
            "run_event_log_missing",
            Box::new(|mut g| {
                g.run_event_log_ref = "missing".to_string();
                g
            }),
        ),
        (
            "answer_packet_missing",
            Box::new(|mut g| {
                g.answer_packet_ref = "missing".to_string();
                g
            }),
        ),
        (
            "abstention_missing",
            Box::new(|mut g| {
                g.abstention_required = false;
                g
            }),
        ),
        (
            "l2_l3_t4_claim",
            Box::new(|mut g| {
                g.l2_l3_t4_claim = true;
                g
            }),
        ),
        (
            "live_gemma_claim",
            Box::new(|mut g| {
                g.live_gemma_claim = true;
                g
            }),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|mut g| {
                g.live_dense_70b_claim = true;
                g
            }),
        ),
        (
            "ssd_as_ram_claim",
            Box::new(|mut g| {
                g.ssd_as_ram_claim = true;
                g
            }),
        ),
    ];

    fixtures
        .drain(..)
        .map(|(name, mutate)| {
            let candidate = mutate(gate.clone());
            (name, candidate.validate().is_err())
        })
        .collect()
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| *candidate == name)
        .map(|(_, pass)| *pass)
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
    let passed = if expected == "non_empty" {
        !value.is_empty()
    } else {
        value == expected
    };
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
            operator: if expected == "non_empty" { "!=" } else { "==" }.to_string(),
            value: serde_json::Value::String(if expected == "non_empty" {
                "".to_string()
            } else {
                expected.to_string()
            }),
            unit: "text".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), passed);
}

fn assert_axis_coverage(measurements: &BTreeMap<String, Measurement>) {
    let missing: Vec<_> = GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_AXES
        .iter()
        .filter(|axis| !measurements.contains_key(**axis))
        .copied()
        .collect();
    assert!(missing.is_empty(), "missing axes: {missing:?}");
}
