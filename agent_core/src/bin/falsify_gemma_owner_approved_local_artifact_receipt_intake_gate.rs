//! `falsify_gemma_owner_approved_local_artifact_receipt_intake_gate`
//!
//! Metadata-only witness for the typed Gemma local-artifact receipt intake
//! boundary. This binds how a future owner-approved receipt may be accepted,
//! while reading no receipt bytes, touching no files, and promoting no route.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaOwnerApprovedLocalArtifactReceiptIntakeGate,
    GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_ID,
    GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_NEXT_CURSOR,
    GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_ID;
const FIXTURE_ID: &str = "gemma_owner_approved_local_artifact_receipt_intake_gate_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_gemma_owner_approved_local_artifact_receipt_intake_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_intake_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_probe/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} sections={} fields={} receipt_kinds={} privacy_rules={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["intake_section_count"].value,
        artifact.measurements["canonical_field_count"].value,
        artifact.measurements["allowed_receipt_kind_count"].value,
        artifact.measurements["privacy_rule_count"].value,
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
    let gate = GemmaOwnerApprovedLocalArtifactReceiptIntakeGate::canonical();
    gate.validate()?;
    let metrics = gate.metrics();
    let red_results = red_fixture_results(&gate);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_receipt_probe_pass", upstream_pass),
        (
            "upstream_receipt_probe_ref_bound",
            gate.upstream_receipt_probe_ref
                == GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_UPSTREAM_REF,
        ),
        (
            "intake_sections_bound",
            metrics.intake_section_count == 8
                && red_pass(&red_results, "missing_intake_section")
                && red_pass(&red_results, "duplicate_intake_section"),
        ),
        (
            "canonical_fields_bound",
            metrics.canonical_field_count == 30
                && red_pass(&red_results, "missing_canonical_field")
                && red_pass(&red_results, "duplicate_canonical_field"),
        ),
        (
            "receipt_kind_policy_bound",
            metrics.allowed_receipt_kind_count == 4
                && red_pass(&red_results, "missing_receipt_kind")
                && red_pass(&red_results, "unknown_receipt_kind"),
        ),
        (
            "privacy_rules_bound",
            metrics.privacy_rule_count == 10
                && red_pass(&red_results, "missing_privacy_rule")
                && red_pass(&red_results, "duplicate_privacy_rule"),
        ),
        (
            "shortcut_and_rejection_policy_bound",
            metrics.denied_shortcut_count == 14
                && metrics.rejection_policy_count == 40
                && red_pass(&red_results, "missing_denied_shortcut")
                && red_pass(&red_results, "duplicate_denied_shortcut")
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "owner_approval_required_but_absent",
            metrics.owner_approval_required_count == 1
                && metrics.owner_approval_granted_count == 0
                && red_pass(&red_results, "owner_approval_not_required")
                && red_pass(&red_results, "owner_approval_granted"),
        ),
        (
            "receipt_payload_deferred",
            metrics.receipt_payload_present_count == 0
                && metrics.receipt_payload_bytes_read == 0
                && metrics.receipt_payload_bytes_written == 0
                && red_pass(&red_results, "receipt_payload_present")
                && red_pass(&red_results, "receipt_payload_bytes_read")
                && red_pass(&red_results, "receipt_payload_bytes_written"),
        ),
        (
            "privacy_leaks_denied",
            metrics.privacy_leak_count == 0
                && red_pass(&red_results, "raw_owner_path_stored")
                && red_pass(&red_results, "owner_phrase_plaintext_stored"),
        ),
        (
            "zero_local_file_or_cli_actions",
            metrics.local_action_count == 0
                && red_pass(&red_results, "path_canonicalized")
                && red_pass(&red_results, "file_opened")
                && red_pass(&red_results, "file_hashed")
                && red_pass(&red_results, "byte_count_verified")
                && red_pass(&red_results, "llama_cli_executed"),
        ),
        (
            "zero_command_server_network_actions",
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
            "no_quality_l2_l3_t4_gemma_70b_or_ssd_claim",
            metrics.promotion_claim_count == 0
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "l2_l3_t4_claim")
                && red_pass(&red_results, "live_gemma_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "gemma_owner_approved_local_artifact_receipt_intake_gate_address_deterministic",
            gate.address()
                == GemmaOwnerApprovedLocalArtifactReceiptIntakeGate::canonical().address(),
        ),
        (
            "next_cursor_bound",
            gate.next_cursor == GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_NEXT_CURSOR,
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
            "intake_section_count",
            metrics.intake_section_count,
            "==",
            8,
            "sections",
        ),
        (
            "canonical_field_count",
            metrics.canonical_field_count,
            "==",
            30,
            "fields",
        ),
        (
            "allowed_receipt_kind_count",
            metrics.allowed_receipt_kind_count,
            "==",
            4,
            "kinds",
        ),
        (
            "privacy_rule_count",
            metrics.privacy_rule_count,
            "==",
            10,
            "rules",
        ),
        (
            "denied_shortcut_count",
            metrics.denied_shortcut_count,
            "==",
            14,
            "shortcuts",
        ),
        (
            "rejection_policy_count",
            metrics.rejection_policy_count,
            "==",
            40,
            "policies",
        ),
        (
            "owner_approval_required_count",
            metrics.owner_approval_required_count,
            "==",
            1,
            "requirements",
        ),
        (
            "owner_approval_granted_count",
            metrics.owner_approval_granted_count,
            "==",
            0,
            "approvals",
        ),
        (
            "receipt_payload_present_count",
            metrics.receipt_payload_present_count,
            "==",
            0,
            "payloads",
        ),
        (
            "receipt_payload_bytes_read",
            metrics.receipt_payload_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "receipt_payload_bytes_written",
            metrics.receipt_payload_bytes_written,
            "==",
            0,
            "bytes",
        ),
        (
            "privacy_leak_count",
            metrics.privacy_leak_count,
            "==",
            0,
            "leaks",
        ),
        (
            "local_action_count",
            metrics.local_action_count,
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
            196_608,
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
        "gemma_owner_approved_local_artifact_receipt_intake_gate_address",
        &gate.address().to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_NEXT_CURSOR,
        GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_NEXT_CURSOR,
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
        notes: "metadata-only F-GemmaOwnerApprovedLocalArtifactReceiptIntakeGate: consumes the receipt probe and freezes the typed intake boundary for a future owner-approved local Gemma artifact receipt. It reads zero receipt bytes, stores zero raw paths or owner phrases, opens zero files, hashes zero files, executes zero llama-cli probes, arms zero commands, loads zero model/runtime/provider bytes, mutates zero RuntimeRouter/System G/settings state, and makes no Gemma L2/L3/T4/user-facing claim.".to_string(),
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
    gate: &GemmaOwnerApprovedLocalArtifactReceiptIntakeGate,
) -> Vec<(&'static str, bool)> {
    let mut fixtures: Vec<(
        &'static str,
        Box<
            dyn Fn(
                GemmaOwnerApprovedLocalArtifactReceiptIntakeGate,
            ) -> GemmaOwnerApprovedLocalArtifactReceiptIntakeGate,
        >,
    )> = vec![
        (
            "missing_intake_section",
            Box::new(|mut g| {
                g.required_intake_sections.pop();
                g
            }),
        ),
        (
            "duplicate_intake_section",
            Box::new(|mut g| {
                g.required_intake_sections
                    .push(g.required_intake_sections[0].clone());
                g
            }),
        ),
        (
            "missing_canonical_field",
            Box::new(|mut g| {
                g.required_canonical_fields.pop();
                g
            }),
        ),
        (
            "duplicate_canonical_field",
            Box::new(|mut g| {
                g.required_canonical_fields
                    .push(g.required_canonical_fields[0].clone());
                g
            }),
        ),
        (
            "missing_receipt_kind",
            Box::new(|mut g| {
                g.allowed_receipt_kinds.pop();
                g
            }),
        ),
        (
            "unknown_receipt_kind",
            Box::new(|mut g| {
                g.allowed_receipt_kinds[0] = "gemma_hidden_cache_auto".to_string();
                g
            }),
        ),
        (
            "missing_privacy_rule",
            Box::new(|mut g| {
                g.required_privacy_rules.pop();
                g
            }),
        ),
        (
            "duplicate_privacy_rule",
            Box::new(|mut g| {
                g.required_privacy_rules
                    .push(g.required_privacy_rules[0].clone());
                g
            }),
        ),
        (
            "missing_denied_shortcut",
            Box::new(|mut g| {
                g.denied_intake_shortcuts.pop();
                g
            }),
        ),
        (
            "duplicate_denied_shortcut",
            Box::new(|mut g| {
                g.denied_intake_shortcuts
                    .push(g.denied_intake_shortcuts[0].clone());
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
            "owner_approval_not_required",
            Box::new(|mut g| {
                g.owner_approval_required = false;
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
            "receipt_payload_present",
            Box::new(|mut g| {
                g.receipt_payload_present = true;
                g
            }),
        ),
        (
            "receipt_payload_bytes_read",
            Box::new(|mut g| {
                g.receipt_payload_bytes_read = 1;
                g
            }),
        ),
        (
            "receipt_payload_bytes_written",
            Box::new(|mut g| {
                g.receipt_payload_bytes_written = 1;
                g
            }),
        ),
        (
            "raw_owner_path_stored",
            Box::new(|mut g| {
                g.stores_raw_owner_path = true;
                g
            }),
        ),
        (
            "owner_phrase_plaintext_stored",
            Box::new(|mut g| {
                g.stores_owner_phrase_plaintext = true;
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
            "llama_cli_executed",
            Box::new(|mut g| {
                g.llama_cli_executed = true;
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
            "quality_claim",
            Box::new(|mut g| {
                g.quality_claim = true;
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
    for axis in GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} for {FALSIFIER_ID}"
        );
    }
}
