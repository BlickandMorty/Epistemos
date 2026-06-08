//! `falsify_tool_execution_surface_release_blocker_card`.
//!
//! Metadata-only witness that binds retained tool-execution release blockers to
//! exact source/canon surfaces before local model agent routes can inherit tool
//! authority.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_tool_execution_surface_invariants, required_tool_execution_surface_source_refs,
    ToolExecutionSurfaceReleaseBlockerWitness, TOOL_EXECUTION_SURFACE_FAMILY_SOURCE_REF,
    TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR, TOOL_EXECUTION_SURFACE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-ToolExecutionSurface-ReleaseBlockerCard";
const FIXTURE_ID: &str = "tool_execution_surface_release_blocker_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_tool_execution_surface_release_blocker_card.sh";
const RESULT: &str = "artifacts/falsifiers/tool_execution_surface_release_blocker_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/source_guard_drift_release_blocker_card/result.json";
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
        artifact.measurements["tool_execution_surface_issue_count"].value,
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
    let witness = ToolExecutionSurfaceReleaseBlockerWitness::new(
        TOOL_EXECUTION_SURFACE_UPSTREAM_REF,
        TOOL_EXECUTION_SURFACE_FAMILY_SOURCE_REF,
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
            "upstream_source_guard_drift_card_pass",
            upstream.overall_pass,
        ),
        (
            "upstream_next_cursor_tool_execution_surface",
            upstream.next_cursor == "tool_execution_surface_release_blocker_card",
        ),
        (
            "tool_execution_surface_family_bound",
            witness.card.family_id == "tool_execution_surface",
        ),
        (
            "tool_execution_surface_issue_count_retained",
            witness.card.issue_count == family.issue_count && witness.card.issue_count == 2,
        ),
        (
            "source_refs_cover_tool_execution_surfaces",
            witness.metrics.source_ref_count == required_tool_execution_surface_source_refs().len(),
        ),
        (
            "focused_commands_cover_tool_execution_tests",
            witness.metrics.focused_command_count >= 6,
        ),
        (
            "tool_execution_invariants_bound",
            witness.metrics.invariant_count == required_tool_execution_surface_invariants().len(),
        ),
        (
            "swift_tool_surfaces_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/LocalAgent/LocalAgentLoop.swift")
                && witness
                    .card
                    .source_refs
                    .iter()
                    .any(|value| value == "Epistemos/LocalAgent/LocalAgentCommandDispatcher.swift")
                && witness
                    .card
                    .source_refs
                    .iter()
                    .any(|value| value == "Epistemos/LocalAgent/LocalToolGrammar.swift"),
        ),
        (
            "rust_tool_registry_and_security_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "agent_core/src/tools/registry.rs")
                && witness
                    .card
                    .source_refs
                    .iter()
                    .any(|value| value == "agent_core/src/security.rs"),
        ),
        (
            "mas_pro_source_guard_doc_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md"),
        ),
        (
            "tool_schema_and_admission_required",
            witness.card.tool_schema_digest_required && witness.card.sovereign_admission_required,
        ),
        (
            "mas_pro_tool_policy_required",
            witness.card.mas_forbidden_tool_denial_required
                && witness.card.pro_tool_owner_approval_required
                && witness.card.mutating_tool_confirmation_required,
        ),
        (
            "subprocess_output_and_visibility_required",
            witness.card.subprocess_hardening_required
                && witness.card.tool_output_sanitization_required
                && witness.card.run_event_log_required
                && witness.card.answer_packet_required,
        ),
        (
            "rollback_or_abstention_required",
            witness.card.rollback_or_abstention_required,
        ),
        (
            "no_hidden_tool_route_authority",
            !witness.card.runtime_router_hidden_tool_authority_allowed
                && !witness
                    .card
                    .eidos_patternboost_lattice_tool_authority_allowed
                && !witness.card.hidden_cloud_or_provider_fallback_allowed,
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
            "zero_tool_model_provider_bytes",
            witness.metrics.tool_execution_bytes_opened == 0
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
            "next_cursor_bound",
            witness.next_cursor == TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
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
            "tool_execution_surface_issue_count",
            witness.card.issue_count,
            2,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_tool_execution_surface_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            6,
            "commands",
        ),
        (
            "tool_execution_invariant_count",
            witness.metrics.invariant_count as u64,
            required_tool_execution_surface_invariants().len() as u64,
            "invariants",
        ),
        (
            "tool_surface_count",
            witness.metrics.surface_count as u64,
            10,
            "surfaces",
        ),
        (
            "tool_execution_bytes_opened_total",
            witness.metrics.tool_execution_bytes_opened,
            0,
            "bytes",
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
        "tool_execution_surface_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "tool_execution_surface_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "tool_execution_surface_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "tool_execution_surface_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "tool_execution_surface_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("tool_execution_surface_card".to_string(), true);

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
            value: serde_json::json!(TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    );

    for axis in TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_AXES {
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
        notes: "metadata-only F-ToolExecutionSurface-ReleaseBlockerCard: consumes source-guard drift and release-audit tool_execution_surface family, binds local agent/tool registry/security/canon refs, rejects hidden tool authority, MAS/Pro leakage, unconfirmed mutation, missing AnswerPacket/RunEventLog, false product green, live dense 70B, SSD-as-RAM, and byte/provider/tool execution leaks; no tools are executed and no model/runtime/provider bytes are opened.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Debug)]
// UAS: uas:tool-execution-surface-release-blocker-card:upstream-source-card
// Plane: Verification.
// Residency: metadata-only upstream witness summary; no source/model bytes.
struct UpstreamSourceGuardCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamSourceGuardCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamSourceGuardCard {
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
// UAS: uas:tool-execution-surface-release-blocker-card:failure-family-source-card
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
                == Some("tool_execution_surface")
        })
        .ok_or("missing tool_execution_surface family")?;
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

fn red_fixture_results(witness: &ToolExecutionSurfaceReleaseBlockerWitness) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "tool_execution_surface_release_blocker_card",
            "tool_execution_surface",
            2,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "source_guard_drift_release_blocker_card",
            "tool_execution_surface",
            2,
        ),
        (
            "wrong_family_rejected",
            true,
            "tool_execution_surface_release_blocker_card",
            "source_guard_drift",
            2,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "tool_execution_surface_release_blocker_card",
            "tool_execution_surface",
            0,
        ),
    ] {
        let rejected = ToolExecutionSurfaceReleaseBlockerWitness::new(
            TOOL_EXECUTION_SURFACE_UPSTREAM_REF,
            TOOL_EXECUTION_SURFACE_FAMILY_SOURCE_REF,
            upstream_pass,
            cursor,
            family,
            issues,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add_card = |id: &str,
                    mutate: fn(&mut agent_core::uas::ToolExecutionSurfaceReleaseBlockerCard),
                    results: &mut Vec<(String, bool)>| {
        let mut card = witness.card.clone();
        mutate(&mut card);
        results.push((id.to_string(), card.validate().is_err()));
    };

    add_card(
        "missing_tool_grammar_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/LocalAgent/LocalToolGrammar.swift")
        },
        &mut results,
    );
    add_card(
        "missing_rust_tool_registry_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "agent_core/src/tools/registry.rs")
        },
        &mut results,
    );
    add_card(
        "missing_mas_pro_doc_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md")
        },
        &mut results,
    );
    add_card(
        "source_refs_duplicate_rejected",
        |card| {
            card.source_refs
                .push("Epistemos/LocalAgent/LocalToolGrammar.swift".to_string())
        },
        &mut results,
    );
    add_card(
        "invariant_missing_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "tool_schema_digest_required")
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
        "tool_schema_digest_missing_rejected",
        |card| card.tool_schema_digest_required = false,
        &mut results,
    );
    add_card(
        "sovereign_admission_missing_rejected",
        |card| card.sovereign_admission_required = false,
        &mut results,
    );
    add_card(
        "mas_forbidden_tool_denial_missing_rejected",
        |card| card.mas_forbidden_tool_denial_required = false,
        &mut results,
    );
    add_card(
        "owner_approval_missing_rejected",
        |card| card.pro_tool_owner_approval_required = false,
        &mut results,
    );
    add_card(
        "mutating_confirmation_missing_rejected",
        |card| card.mutating_tool_confirmation_required = false,
        &mut results,
    );
    add_card(
        "subprocess_hardening_missing_rejected",
        |card| card.subprocess_hardening_required = false,
        &mut results,
    );
    add_card(
        "tool_output_sanitization_missing_rejected",
        |card| card.tool_output_sanitization_required = false,
        &mut results,
    );
    add_card(
        "run_event_log_missing_rejected",
        |card| card.run_event_log_required = false,
        &mut results,
    );
    add_card(
        "answer_packet_missing_rejected",
        |card| card.answer_packet_required = false,
        &mut results,
    );
    add_card(
        "rollback_or_abstention_missing_rejected",
        |card| card.rollback_or_abstention_required = false,
        &mut results,
    );
    add_card(
        "hidden_runtime_tool_authority_rejected",
        |card| card.runtime_router_hidden_tool_authority_allowed = true,
        &mut results,
    );
    add_card(
        "hidden_lattice_eidos_patternboost_tool_authority_rejected",
        |card| card.eidos_patternboost_lattice_tool_authority_allowed = true,
        &mut results,
    );
    add_card(
        "hidden_cloud_fallback_allowed_rejected",
        |card| card.hidden_cloud_or_provider_fallback_allowed = true,
        &mut results,
    );
    add_card(
        "tool_execution_bytes_opened_nonzero_rejected",
        |card| card.tool_execution_bytes_opened = 1,
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
        let witness = ToolExecutionSurfaceReleaseBlockerWitness::new(
            TOOL_EXECUTION_SURFACE_UPSTREAM_REF,
            TOOL_EXECUTION_SURFACE_FAMILY_SOURCE_REF,
            true,
            "tool_execution_surface_release_blocker_card",
            "tool_execution_surface",
            2,
        )
        .expect("valid witness");
        let results = red_fixture_results(&witness);
        assert!(results.len() >= 25);
        assert!(
            results.iter().all(|(_, rejected)| *rejected),
            "all red fixtures must reject: {results:?}"
        );
    }
}
