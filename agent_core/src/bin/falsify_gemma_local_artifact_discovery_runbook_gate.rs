//! `falsify_gemma_local_artifact_discovery_runbook_gate`
//!
//! Metadata-only runbook gate for discovering local Gemma artifacts. It proves
//! future discovery must be owner-approved, symbolic-root based, redacted, and
//! non-promotional before any local artifact receipt or runtime proof can run.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaLocalArtifactDiscoveryRunbookGate, GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_ID,
    GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_NEXT_CURSOR,
    GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_ID;
const FIXTURE_ID: &str = "gemma_local_artifact_discovery_runbook_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_local_artifact_discovery_runbook_gate.sh";
const RESULT: &str = "artifacts/falsifiers/gemma_local_artifact_discovery_runbook_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_official_convenience_command_denylist_gate/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} symbolic_roots={} patterns={} file_actions={} runtime_actions={} candidate_promotions={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["symbolic_search_root_count"].value,
        artifact.measurements["expected_artifact_pattern_count"].value,
        artifact.measurements["file_action_count"].value,
        artifact.measurements["runtime_action_count"].value,
        artifact.measurements["candidate_promotion_count"].value,
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
    let gate = GemmaLocalArtifactDiscoveryRunbookGate::canonical();
    gate.validate()?;
    let metrics = gate.metrics();
    let red_results = red_fixture_results(&gate);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_convenience_denylist_gate_pass", upstream_pass),
        (
            "upstream_convenience_denylist_gate_ref_bound",
            gate.upstream_denylist_gate_ref
                == GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_UPSTREAM_REF,
        ),
        (
            "symbolic_roots_bound",
            metrics.symbolic_search_root_count == 4
                && red_pass(&red_results, "missing_symbolic_root")
                && red_pass(&red_results, "duplicate_symbolic_root"),
        ),
        (
            "expected_artifact_patterns_bound",
            metrics.expected_artifact_pattern_count == 4
                && red_pass(&red_results, "missing_artifact_pattern")
                && red_pass(&red_results, "duplicate_artifact_pattern"),
        ),
        (
            "discovery_rules_bound",
            metrics.discovery_rule_count == 18 && red_pass(&red_results, "missing_discovery_rule"),
        ),
        (
            "rejection_policies_bound",
            metrics.rejection_policy_count == 30
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "owner_approval_absent_and_scan_deferred",
            metrics.owner_approval_granted_count == 0
                && red_pass(&red_results, "owner_approval_granted"),
        ),
        (
            "raw_path_denied",
            metrics.raw_path_storage_count == 0 && red_pass(&red_results, "raw_path_stored"),
        ),
        (
            "zero_file_path_hash_actions",
            metrics.file_action_count == 0
                && red_pass(&red_results, "path_canonicalized")
                && red_pass(&red_results, "file_opened")
                && red_pass(&red_results, "file_hashed")
                && red_pass(&red_results, "byte_count_verified"),
        ),
        (
            "zero_runtime_network_server_actions",
            metrics.runtime_action_count == 0
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "server_started")
                && red_pass(&red_results, "network_probe_allowed"),
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
                && red_pass(&red_results, "hidden_eidos_authority")
                && red_pass(&red_results, "hidden_lattice_authority")
                && red_pass(&red_results, "hidden_patternboost_authority")
                && red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "candidate_discovery_non_promotional",
            metrics.candidate_promotion_count == 0
                && red_pass(&red_results, "candidate_found_promotes_receipt"),
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
            "gemma_local_artifact_discovery_runbook_gate_address_deterministic",
            gate.address() == GemmaLocalArtifactDiscoveryRunbookGate::canonical().address(),
        ),
        (
            "next_cursor_bound",
            gate.next_cursor == GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_NEXT_CURSOR,
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
            "symbolic_search_root_count",
            metrics.symbolic_search_root_count,
            "==",
            4,
            "roots",
        ),
        (
            "expected_artifact_pattern_count",
            metrics.expected_artifact_pattern_count,
            "==",
            4,
            "patterns",
        ),
        (
            "discovery_rule_count",
            metrics.discovery_rule_count,
            "==",
            18,
            "rules",
        ),
        (
            "rejection_policy_count",
            metrics.rejection_policy_count,
            "==",
            30,
            "policies",
        ),
        (
            "owner_approval_granted_count",
            metrics.owner_approval_granted_count,
            "==",
            0,
            "approvals",
        ),
        (
            "raw_path_storage_count",
            metrics.raw_path_storage_count,
            "==",
            0,
            "paths",
        ),
        (
            "file_action_count",
            metrics.file_action_count,
            "==",
            0,
            "actions",
        ),
        (
            "runtime_action_count",
            metrics.runtime_action_count,
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
            "candidate_promotion_count",
            metrics.candidate_promotion_count,
            "==",
            0,
            "promotions",
        ),
        (
            "promotion_claim_count",
            metrics.promotion_claim_count,
            "==",
            0,
            "claims",
        ),
        (
            "metadata_bytes",
            metrics.metadata_bytes,
            "<=",
            98_304,
            "bytes",
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
        "gemma_local_artifact_discovery_runbook_gate_address",
        &gate.address().to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_NEXT_CURSOR,
        GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_NEXT_CURSOR,
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
        notes: "metadata-only F-GemmaLocalArtifactDiscoveryRunbookGate: consumes the Gemma convenience-command denylist and defines a bounded, symbolic-root, owner-approved, raw-path-redacted discovery runbook. It scans zero paths, opens zero files, hashes zero model bytes, arms zero commands, starts zero servers, performs zero provider calls, mutates no RuntimeRouter/System G/settings/default state, and makes no Gemma L2/L3/T4/user-facing claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_gate_pass(path: &str) -> Result<bool, Box<dyn std::error::Error>> {
    if !Path::new(path).exists() {
        return Ok(false);
    }
    let bytes = std::fs::read(path)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(json
        .get("overall_pass")
        .and_then(|value| value.as_bool())
        .unwrap_or(false))
}

fn red_fixture_results(gate: &GemmaLocalArtifactDiscoveryRunbookGate) -> Vec<(&'static str, bool)> {
    let mut fixtures: Vec<(
        &'static str,
        Box<
            dyn Fn(
                GemmaLocalArtifactDiscoveryRunbookGate,
            ) -> GemmaLocalArtifactDiscoveryRunbookGate,
        >,
    )> = vec![
        (
            "missing_symbolic_root",
            Box::new(|mut g| {
                g.symbolic_search_roots.pop();
                g
            }),
        ),
        (
            "duplicate_symbolic_root",
            Box::new(|mut g| {
                g.symbolic_search_roots
                    .push(g.symbolic_search_roots[0].clone());
                g
            }),
        ),
        (
            "missing_artifact_pattern",
            Box::new(|mut g| {
                g.expected_artifact_patterns.pop();
                g
            }),
        ),
        (
            "duplicate_artifact_pattern",
            Box::new(|mut g| {
                g.expected_artifact_patterns
                    .push(g.expected_artifact_patterns[0].clone());
                g
            }),
        ),
        (
            "missing_discovery_rule",
            Box::new(|mut g| {
                g.required_discovery_rules.pop();
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
            "owner_approval_granted",
            Box::new(|mut g| {
                g.owner_approval_granted = true;
                g
            }),
        ),
        (
            "raw_path_stored",
            Box::new(|mut g| {
                g.raw_path_stored = true;
                g
            }),
        ),
        (
            "path_canonicalized",
            Box::new(|mut g| {
                g.path_canonicalization_count = 1;
                g
            }),
        ),
        (
            "file_opened",
            Box::new(|mut g| {
                g.file_open_count = 1;
                g
            }),
        ),
        (
            "file_hashed",
            Box::new(|mut g| {
                g.file_hash_count = 1;
                g
            }),
        ),
        (
            "byte_count_verified",
            Box::new(|mut g| {
                g.byte_count_verified = true;
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
            "network_probe_allowed",
            Box::new(|mut g| {
                g.network_probe_allowed = true;
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
            "hidden_eidos_authority",
            Box::new(|mut g| {
                g.hidden_eidos_authority = true;
                g
            }),
        ),
        (
            "hidden_lattice_authority",
            Box::new(|mut g| {
                g.hidden_lattice_authority = true;
                g
            }),
        ),
        (
            "hidden_patternboost_authority",
            Box::new(|mut g| {
                g.hidden_patternboost_authority = true;
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
            "candidate_found_promotes_receipt",
            Box::new(|mut g| {
                g.candidate_found_promotes_receipt = true;
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
    let missing: Vec<_> = GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_AXES
        .iter()
        .filter(|axis| !measurements.contains_key(**axis))
        .copied()
        .collect();
    assert!(missing.is_empty(), "missing axes: {missing:?}");
}
