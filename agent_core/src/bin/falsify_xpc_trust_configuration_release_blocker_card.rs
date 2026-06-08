//! `falsify_xpc_trust_configuration_release_blocker_card`.
//!
//! Metadata-only witness that binds XPC trust configuration release blockers to
//! exact source/canon surfaces before local model or provider routes can inherit
//! XPC authority.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_xpc_trust_configuration_invariants, required_xpc_trust_configuration_source_refs,
    XpcTrustConfigurationReleaseBlockerWitness, XPC_TRUST_CONFIGURATION_FAMILY_SOURCE_REF,
    XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR, XPC_TRUST_CONFIGURATION_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-XpcTrustConfiguration-ReleaseBlockerCard";
const FIXTURE_ID: &str = "xpc_trust_configuration_release_blocker_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_xpc_trust_configuration_release_blocker_card.sh";
const RESULT: &str =
    "artifacts/falsifiers/xpc_trust_configuration_release_blocker_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/tool_execution_surface_release_blocker_card/result.json";
const FAMILY_SOURCE_RESULT: &str =
    "artifacts/falsifiers/release_audit_failure_family_source_card/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} issue_count={} source_refs={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["xpc_trust_configuration_issue_count"].value,
        artifact.measurements["source_ref_count"].value,
    );
    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let upstream = read_upstream()?;
    let family = read_family_source()?;
    let witness = XpcTrustConfigurationReleaseBlockerWitness::new(
        XPC_TRUST_CONFIGURATION_UPSTREAM_REF,
        XPC_TRUST_CONFIGURATION_FAMILY_SOURCE_REF,
        upstream.overall_pass,
        &upstream.next_cursor,
        &family.family_id,
        family.issue_count,
    )?;
    witness.validate()?;
    let red_results = red_fixture_results(&witness);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let red_fixture_count = red_results.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        (
            "upstream_tool_execution_surface_card_pass",
            upstream.overall_pass,
        ),
        (
            "upstream_next_cursor_xpc_trust_configuration",
            upstream.next_cursor == "xpc_trust_configuration_release_blocker_card",
        ),
        (
            "xpc_trust_configuration_family_bound",
            witness.card.family_id == "xpc_trust_configuration",
        ),
        (
            "xpc_trust_configuration_issue_count_retained",
            witness.card.issue_count == family.issue_count && witness.card.issue_count == 1,
        ),
        (
            "source_refs_cover_xpc_trust_surfaces",
            witness.metrics.source_ref_count
                == required_xpc_trust_configuration_source_refs().len(),
        ),
        (
            "focused_commands_cover_xpc_trust_tests",
            witness.metrics.focused_command_count >= 5,
        ),
        (
            "xpc_trust_invariants_bound",
            witness.metrics.invariant_count == required_xpc_trust_configuration_invariants().len(),
        ),
        (
            "xpc_trust_requirement_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/XPC/XPCTrust.swift"),
        ),
        (
            "agent_and_provider_clients_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/XPC/AgentServiceClient.swift")
                && witness
                    .card
                    .source_refs
                    .iter()
                    .any(|value| value == "Epistemos/XPC/ProviderServiceClient.swift"),
        ),
        (
            "xpc_smoke_and_capability_bridge_tests_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "EpistemosTests/XPCSmokeTests.swift")
                && witness
                    .card
                    .source_refs
                    .iter()
                    .any(|value| value == "EpistemosTests/CapabilityBridgeTests.swift"),
        ),
        (
            "xpc_research_canon_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "docs/fusion/XPC_RESEARCH_INTAKE_2026_05_04.md")
                && witness
                    .card
                    .source_refs
                    .iter()
                    .any(|value| value == "docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md"),
        ),
        (
            "code_signing_requirement_before_resume_required",
            witness.card.code_signing_requirement_before_resume_required
                && witness.card.anchor_apple_generic_required
                && witness.card.service_identifier_required
                && witness.card.team_ou_required,
        ),
        (
            "client_trust_and_team_drift_guard_required",
            witness.card.development_team_drift_guard_required
                && witness.card.agent_client_trust_requirement_required
                && witness.card.provider_client_trust_requirement_required,
        ),
        (
            "capability_bridge_subject_split_required",
            witness.card.capability_bridge_subject_split_required,
        ),
        (
            "no_process_id_or_unwhitelisted_payload_trust",
            !witness.card.process_identifier_trust_allowed
                && !witness.card.unwhitelisted_payload_claimed,
        ),
        (
            "no_cloud_tool_or_hidden_xpc_promotion",
            !witness.card.cloud_or_tool_execution_promoted
                && !witness.card.hidden_provider_or_xpc_fallback_allowed,
        ),
        (
            "no_l2_l3_product_green",
            !witness.card.l2_green_claimed
                && !witness.card.l3_green_claimed
                && !witness.card.product_green_claimed,
        ),
        (
            "no_live_dense_70b_or_ssd_as_ram_claim",
            !witness.card.live_dense_70b_claimed && !witness.card.ssd_as_ram_claimed,
        ),
        (
            "zero_xpc_tool_model_provider_bytes",
            witness.metrics.xpc_connections_opened == 0
                && witness.metrics.xpc_services_launched == 0
                && witness.metrics.tool_commands_executed == 0
                && witness.metrics.model_runtime_bytes_loaded == 0
                && witness.metrics.provider_calls_made == 0,
        ),
        (
            "rollback_run_event_answer_packet_refs_present",
            !witness.card.rollback_ref.is_empty()
                && !witness.card.run_event_log_ref.is_empty()
                && !witness.card.answer_packet_ref.is_empty(),
        ),
        (
            "next_cursor_returns_to_guard_bottleneck",
            witness.next_cursor == XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
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

    for (id, passed) in &red_results {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            id,
            *passed,
        );
    }

    for (name, actual, expected, unit) in [
        (
            "xpc_trust_configuration_issue_count",
            witness.card.issue_count,
            1,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_xpc_trust_configuration_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            5,
            "commands",
        ),
        (
            "xpc_trust_invariant_count",
            witness.metrics.invariant_count as u64,
            required_xpc_trust_configuration_invariants().len() as u64,
            "invariants",
        ),
        (
            "xpc_trust_surface_count",
            witness.metrics.surface_count as u64,
            10,
            "surfaces",
        ),
        (
            "xpc_connections_opened_total",
            witness.metrics.xpc_connections_opened,
            0,
            "connections",
        ),
        (
            "xpc_services_launched_total",
            witness.metrics.xpc_services_launched,
            0,
            "services",
        ),
        (
            "tool_commands_executed_total",
            witness.metrics.tool_commands_executed,
            0,
            "commands",
        ),
        (
            "model_runtime_bytes_loaded_total",
            witness.metrics.model_runtime_bytes_loaded,
            0,
            "bytes",
        ),
        (
            "provider_calls_made_total",
            witness.metrics.provider_calls_made,
            0,
            "calls",
        ),
        (
            "red_fixture_count",
            red_fixture_count,
            red_fixture_count,
            "fixtures",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            red_fixture_count,
            "fixtures",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            actual,
            "==",
            expected,
            unit,
        );
    }

    measurements.insert(
        "xpc_trust_configuration_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "xpc_trust_configuration_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "xpc_trust_configuration_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "xpc_trust_configuration_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "xpc_trust_configuration_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("xpc_trust_configuration_card".to_string(), true);

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(witness.next_cursor),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "eq".to_string(),
            value: serde_json::json!(XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    );

    for axis in XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_AXES {
        measurements
            .entry((*axis).to_string())
            .or_insert(Measurement {
                value: serde_json::json!(false),
                unit: "axis_missing".to_string(),
            });
        thresholds
            .entry((*axis).to_string())
            .or_insert(AcceptanceThreshold {
                operator: "present".to_string(),
                value: serde_json::json!(true),
                unit: "axis_missing".to_string(),
            });
        pass_per_axis.entry((*axis).to_string()).or_insert(false);
    }

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
        notes: "metadata-only F-XpcTrustConfiguration-ReleaseBlockerCard: consumes tool-execution surface and release-audit xpc_trust_configuration family, binds XPC trust requirement/client/service/test/canon refs, preserves Apple's before-resume code-signing requirement semantics, rejects process-identifier trust, unwhitelisted payload claims, hidden provider/XPC fallback, false L2/L3/product green, live dense 70B, SSD-as-RAM, and XPC/tool/model/provider byte leaks; no XPC service is launched and no model/runtime/provider bytes are opened.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Debug)]
// UAS: uas:xpc-trust-configuration-release-blocker-card:upstream-tool-card
// Plane: Verification.
// Residency: metadata-only upstream witness summary; no XPC/model bytes.
struct UpstreamToolExecutionCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamToolExecutionCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamToolExecutionCard {
        overall_pass: json
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false),
        next_cursor: json
            .pointer("/measurements/next_cursor/value")
            .and_then(serde_json::Value::as_str)
            .unwrap_or_default()
            .to_string(),
    })
}

#[derive(Debug)]
// UAS: uas:xpc-trust-configuration-release-blocker-card:failure-family-source-card
// Plane: Verification.
// Residency: metadata-only release-audit family summary; no source bytes opened.
struct FamilySourceCard {
    family_id: String,
    issue_count: u64,
}

fn read_family_source() -> Result<FamilySourceCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(FAMILY_SOURCE_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    let cards = json
        .pointer("/measurements/failure_family_cards/value")
        .and_then(serde_json::Value::as_array)
        .ok_or("missing failure_family_cards")?;
    let family = cards
        .iter()
        .find(|card| {
            card.get("family_id").and_then(serde_json::Value::as_str)
                == Some("xpc_trust_configuration")
        })
        .ok_or("missing xpc_trust_configuration family")?;
    Ok(FamilySourceCard {
        family_id: family
            .get("family_id")
            .and_then(serde_json::Value::as_str)
            .unwrap_or_default()
            .to_string(),
        issue_count: family
            .get("issue_count")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0),
    })
}

fn red_fixture_results(
    witness: &XpcTrustConfigurationReleaseBlockerWitness,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "xpc_trust_configuration_release_blocker_card",
            "xpc_trust_configuration",
            1,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "tool_execution_surface_release_blocker_card",
            "xpc_trust_configuration",
            1,
        ),
        (
            "wrong_family_rejected",
            true,
            "xpc_trust_configuration_release_blocker_card",
            "tool_execution_surface",
            1,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "xpc_trust_configuration_release_blocker_card",
            "xpc_trust_configuration",
            0,
        ),
    ] {
        let rejected = XpcTrustConfigurationReleaseBlockerWitness::new(
            XPC_TRUST_CONFIGURATION_UPSTREAM_REF,
            XPC_TRUST_CONFIGURATION_FAMILY_SOURCE_REF,
            upstream_pass,
            cursor,
            family,
            issues,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add_card = |id: &str,
                    mutate: fn(&mut agent_core::uas::XpcTrustConfigurationReleaseBlockerCard),
                    results: &mut Vec<(String, bool)>| {
        let mut card = witness.card.clone();
        mutate(&mut card);
        results.push((id.to_string(), card.validate().is_err()));
    };

    add_card(
        "missing_xpc_trust_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/XPC/XPCTrust.swift")
        },
        &mut results,
    );
    add_card(
        "missing_agent_client_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/XPC/AgentServiceClient.swift")
        },
        &mut results,
    );
    add_card(
        "missing_provider_client_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/XPC/ProviderServiceClient.swift")
        },
        &mut results,
    );
    add_card(
        "missing_xpc_smoke_tests_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "EpistemosTests/XPCSmokeTests.swift")
        },
        &mut results,
    );
    add_card(
        "source_refs_duplicate_rejected",
        |card| {
            card.source_refs
                .push("Epistemos/XPC/XPCTrust.swift".to_string())
        },
        &mut results,
    );
    add_card(
        "invariant_missing_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "code_signing_requirement_before_resume_required")
        },
        &mut results,
    );
    add_card(
        "focused_command_too_broad_rejected",
        |card| {
            card.focused_commands[0] = "xcodebuild test -only-testing:EpistemosTests".to_string()
        },
        &mut results,
    );
    add_card(
        "app_group_names_missing_rejected",
        |card| card.app_group_service_names_required = false,
        &mut results,
    );
    add_card(
        "before_resume_requirement_missing_rejected",
        |card| card.code_signing_requirement_before_resume_required = false,
        &mut results,
    );
    add_card(
        "anchor_apple_generic_missing_rejected",
        |card| card.anchor_apple_generic_required = false,
        &mut results,
    );
    add_card(
        "service_identifier_missing_rejected",
        |card| card.service_identifier_required = false,
        &mut results,
    );
    add_card(
        "team_ou_missing_rejected",
        |card| card.team_ou_required = false,
        &mut results,
    );
    add_card(
        "team_drift_guard_missing_rejected",
        |card| card.development_team_drift_guard_required = false,
        &mut results,
    );
    add_card(
        "agent_client_trust_missing_rejected",
        |card| card.agent_client_trust_requirement_required = false,
        &mut results,
    );
    add_card(
        "provider_client_trust_missing_rejected",
        |card| card.provider_client_trust_requirement_required = false,
        &mut results,
    );
    add_card(
        "capability_bridge_subject_split_missing_rejected",
        |card| card.capability_bridge_subject_split_required = false,
        &mut results,
    );
    add_card(
        "process_identifier_trust_allowed_rejected",
        |card| card.process_identifier_trust_allowed = true,
        &mut results,
    );
    add_card(
        "unwhitelisted_payload_claimed_rejected",
        |card| card.unwhitelisted_payload_claimed = true,
        &mut results,
    );
    add_card(
        "cloud_or_tool_execution_promoted_rejected",
        |card| card.cloud_or_tool_execution_promoted = true,
        &mut results,
    );
    add_card(
        "hidden_xpc_provider_fallback_rejected",
        |card| card.hidden_provider_or_xpc_fallback_allowed = true,
        &mut results,
    );
    add_card(
        "xpc_connections_opened_nonzero_rejected",
        |card| card.xpc_connections_opened = 1,
        &mut results,
    );
    add_card(
        "xpc_services_launched_nonzero_rejected",
        |card| card.xpc_services_launched = 1,
        &mut results,
    );
    add_card(
        "tool_commands_executed_nonzero_rejected",
        |card| card.tool_commands_executed = 1,
        &mut results,
    );
    add_card(
        "model_runtime_bytes_loaded_nonzero_rejected",
        |card| card.model_runtime_bytes_loaded = 1,
        &mut results,
    );
    add_card(
        "provider_calls_nonzero_rejected",
        |card| card.provider_calls_made = 1,
        &mut results,
    );
    add_card(
        "l2_l3_product_green_claimed_rejected",
        |card| {
            card.l2_green_claimed = true;
            card.l3_green_claimed = true;
            card.product_green_claimed = true;
        },
        &mut results,
    );
    add_card(
        "live_dense_70b_claimed_rejected",
        |card| card.live_dense_70b_claimed = true,
        &mut results,
    );
    add_card(
        "ssd_as_ram_claimed_rejected",
        |card| card.ssd_as_ram_claimed = true,
        &mut results,
    );

    results
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn red_fixture_suite_rejects_all_mutants() {
        let witness = XpcTrustConfigurationReleaseBlockerWitness::new(
            XPC_TRUST_CONFIGURATION_UPSTREAM_REF,
            XPC_TRUST_CONFIGURATION_FAMILY_SOURCE_REF,
            true,
            "xpc_trust_configuration_release_blocker_card",
            "xpc_trust_configuration",
            1,
        )
        .expect("valid witness");
        let results = red_fixture_results(&witness);
        assert!(results.len() >= 28);
        assert!(
            results.iter().all(|(_, rejected)| *rejected),
            "all red fixtures must reject: {results:?}"
        );
    }
}
