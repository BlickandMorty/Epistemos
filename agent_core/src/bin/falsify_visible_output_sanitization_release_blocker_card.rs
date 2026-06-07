//! `falsify_visible_output_sanitization_release_blocker_card`.
//!
//! Metadata-only witness that keeps hidden reasoning, tool payloads, and
//! control envelopes out of user-visible output before release readiness can
//! promote.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_visible_output_sanitization_invariants,
    required_visible_output_sanitization_source_refs,
    VisibleOutputSanitizationReleaseBlockerWitness, VISIBLE_OUTPUT_SANITIZATION_FAMILY_SOURCE_REF,
    VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    VISIBLE_OUTPUT_SANITIZATION_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-VisibleOutputSanitization-ReleaseBlockerCard";
const FIXTURE_ID: &str = "visible_output_sanitization_release_blocker_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_visible_output_sanitization_release_blocker_card.sh";
const RESULT: &str =
    "artifacts/falsifiers/visible_output_sanitization_release_blocker_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/agent_route_policy_large_model_no_hidden_authority/result.json";
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
        artifact.measurements["visible_output_issue_count"].value,
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
    let witness = VisibleOutputSanitizationReleaseBlockerWitness::new(
        VISIBLE_OUTPUT_SANITIZATION_UPSTREAM_REF,
        VISIBLE_OUTPUT_SANITIZATION_FAMILY_SOURCE_REF,
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
        ("upstream_agent_route_card_pass", upstream.overall_pass),
        (
            "upstream_next_cursor_visible_output",
            upstream.next_cursor == "visible_output_sanitization_release_blocker_card",
        ),
        (
            "visible_output_family_bound",
            witness.card.family_id == "visible_output_sanitization",
        ),
        (
            "visible_output_issue_count_retained",
            witness.card.issue_count == family.issue_count && witness.card.issue_count == 5,
        ),
        (
            "source_refs_cover_visible_output_surfaces",
            witness.metrics.source_ref_count
                == required_visible_output_sanitization_source_refs().len(),
        ),
        (
            "focused_commands_cover_visible_output_tests",
            witness.metrics.focused_command_count >= 4,
        ),
        (
            "visible_output_invariants_bound",
            witness.metrics.invariant_count
                == required_visible_output_sanitization_invariants().len(),
        ),
        (
            "user_facing_model_output_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Engine/Extensions.swift"),
        ),
        (
            "user_facing_model_output_tests_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "EpistemosTests/UserFacingModelOutputTests.swift"),
        ),
        (
            "no_raw_function_call_visible",
            !witness.card.raw_function_call_visible,
        ),
        ("no_raw_action_visible", !witness.card.raw_action_visible),
        (
            "no_raw_tool_json_visible",
            !witness.card.raw_tool_json_visible,
        ),
        (
            "no_hidden_reasoning_visible",
            !witness.card.hidden_reasoning_visible,
        ),
        (
            "no_control_prelude_without_answer",
            !witness.card.control_prelude_visible_without_answer,
        ),
        (
            "explicit_final_answer_preserved",
            !witness.card.explicit_final_answer_dropped,
        ),
        (
            "answer_packet_caveat_present",
            !witness.card.answer_packet_caveat_missing,
        ),
        (
            "no_hidden_route_or_cloud_authority",
            !witness.card.hidden_route_authority && !witness.card.hidden_cloud_fallback,
        ),
        (
            "no_l2_l3_product_green",
            !witness.card.l2_green_claimed
                && !witness.card.l3_green_claimed
                && !witness.card.product_green_claimed,
        ),
        (
            "no_live_dense_70b_claim",
            !witness.card.live_dense_70b_claimed,
        ),
        (
            "no_model_runtime_bytes",
            witness.metrics.model_runtime_bytes_loaded == 0,
        ),
        (
            "rollback_run_event_answer_packet_refs_present",
            !witness.card.rollback_ref.is_empty()
                && !witness.card.run_event_log_ref.is_empty()
                && !witness.card.answer_packet_ref.is_empty(),
        ),
        (
            "next_cursor_bound",
            witness.next_cursor == VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
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
            "visible_output_issue_count",
            witness.card.issue_count,
            5,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_visible_output_sanitization_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            4,
            "commands",
        ),
        (
            "visible_output_invariant_count",
            witness.metrics.invariant_count as u64,
            required_visible_output_sanitization_invariants().len() as u64,
            "invariants",
        ),
        (
            "model_runtime_bytes_loaded_total",
            witness.metrics.model_runtime_bytes_loaded,
            0,
            "bytes",
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
        "visible_output_sanitization_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "visible_output_sanitization_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "visible_output_sanitization_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "visible_output_sanitization_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "visible_output_sanitization_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("visible_output_sanitization_card".to_string(), true);

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
            value: serde_json::json!(VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    );

    for axis in VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_AXES {
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
        notes: "metadata-only F-VisibleOutputSanitization-ReleaseBlockerCard: consumes the agent-route blocker and release-audit family source card, binds visible_output_sanitization issue count 5 to exact UserFacingModelOutput and chat-surface source refs, focused tests, privacy/output invariants, rollback, RunEventLog, AnswerPacket, and rejects function/action/tool payload leaks, hidden reasoning visibility, control-prelude leakage, dropped final answers, missing packet caveats, hidden route/cloud authority, runtime byte loads, L2/L3/product green, and live dense-70B claims.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:visible-output-sanitization-release-blocker-card:upstream-parser
// Plane: Verification.
// Residency: metadata-only; reads artifact JSON only.
#[derive(Debug)]
struct UpstreamAgentRouteCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamAgentRouteCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamAgentRouteCard {
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

// UAS: uas:visible-output-sanitization-release-blocker-card:family-parser
// Plane: Verification.
// Residency: metadata-only; reads retained failure-family JSON only.
#[derive(Debug)]
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
    let visible_output = cards
        .iter()
        .find(|card| {
            card.get("family_id").and_then(serde_json::Value::as_str)
                == Some("visible_output_sanitization")
        })
        .ok_or("missing visible_output_sanitization family")?;
    Ok(FamilySourceCard {
        family_id: visible_output
            .get("family_id")
            .and_then(serde_json::Value::as_str)
            .unwrap_or_default()
            .to_string(),
        issue_count: visible_output
            .get("issue_count")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0),
    })
}

fn red_fixture_results(
    witness: &VisibleOutputSanitizationReleaseBlockerWitness,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "visible_output_sanitization_release_blocker_card",
            "visible_output_sanitization",
            5,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "agent_route_policy_large_model_no_hidden_authority",
            "visible_output_sanitization",
            5,
        ),
        (
            "wrong_family_rejected",
            true,
            "visible_output_sanitization_release_blocker_card",
            "agent_route_policy",
            21,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "visible_output_sanitization_release_blocker_card",
            "visible_output_sanitization",
            0,
        ),
    ] {
        let rejected = VisibleOutputSanitizationReleaseBlockerWitness::new(
            VISIBLE_OUTPUT_SANITIZATION_UPSTREAM_REF,
            VISIBLE_OUTPUT_SANITIZATION_FAMILY_SOURCE_REF,
            upstream_pass,
            cursor,
            family,
            issues,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add_card =
        |id: &str,
         mutate: fn(&mut agent_core::uas::VisibleOutputSanitizationReleaseBlockerCard),
         results: &mut Vec<(String, bool)>| {
            let mut card = witness.card.clone();
            mutate(&mut card);
            results.push((id.to_string(), card.validate().is_err()));
        };
    add_card(
        "missing_extensions_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Engine/Extensions.swift")
        },
        &mut results,
    );
    add_card(
        "missing_final_answer_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "explicit_final_answer_survives_after_control_envelopes")
        },
        &mut results,
    );
    add_card(
        "raw_function_call_visible_rejected",
        |card| card.raw_function_call_visible = true,
        &mut results,
    );
    add_card(
        "raw_action_visible_rejected",
        |card| card.raw_action_visible = true,
        &mut results,
    );
    add_card(
        "raw_tool_json_visible_rejected",
        |card| card.raw_tool_json_visible = true,
        &mut results,
    );
    add_card(
        "hidden_reasoning_visible_rejected",
        |card| card.hidden_reasoning_visible = true,
        &mut results,
    );
    add_card(
        "control_prelude_visible_without_answer_rejected",
        |card| card.control_prelude_visible_without_answer = true,
        &mut results,
    );
    add_card(
        "explicit_final_answer_dropped_rejected",
        |card| card.explicit_final_answer_dropped = true,
        &mut results,
    );
    add_card(
        "answer_packet_caveat_missing_rejected",
        |card| card.answer_packet_caveat_missing = true,
        &mut results,
    );
    add_card(
        "hidden_route_cloud_authority_rejected",
        |card| {
            card.hidden_route_authority = true;
            card.hidden_cloud_fallback = true;
        },
        &mut results,
    );
    add_card(
        "l2_l3_product_green_claim_rejected",
        |card| {
            card.l2_green_claimed = true;
            card.l3_green_claimed = true;
            card.product_green_claimed = true;
        },
        &mut results,
    );
    add_card(
        "live_dense_70b_claim_rejected",
        |card| card.live_dense_70b_claimed = true,
        &mut results,
    );
    add_card(
        "model_runtime_byte_leak_rejected",
        |card| card.model_runtime_bytes_loaded = 1,
        &mut results,
    );

    results
}
