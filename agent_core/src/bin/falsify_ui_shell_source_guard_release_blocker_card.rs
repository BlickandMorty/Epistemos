//! `falsify_ui_shell_source_guard_release_blocker_card`.
//!
//! Metadata-only witness that binds retained UI shell source-guard blockers to
//! exact AppEnvironment, shell, settings, runtime-truth, Mini Chat, and test
//! surfaces without granting route, runtime, WRV, MAS, L2, L3, or product proof.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_ui_shell_source_guard_invariants, required_ui_shell_source_guard_source_refs,
    UiShellSourceGuardReleaseBlockerWitness, UI_SHELL_SOURCE_GUARD_FAMILY_SOURCE_REF,
    UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_NEXT_CURSOR, UI_SHELL_SOURCE_GUARD_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-UiShellSourceGuard-ReleaseBlockerCard";
const FIXTURE_ID: &str = "ui_shell_source_guard_release_blocker_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_ui_shell_source_guard_release_blocker_card.sh";
const RESULT: &str = "artifacts/falsifiers/ui_shell_source_guard_release_blocker_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/editor_epdoc_surface_release_blocker_card/result.json";
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
        artifact.measurements["ui_shell_source_guard_issue_count"].value,
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
    let witness = UiShellSourceGuardReleaseBlockerWitness::new(
        UI_SHELL_SOURCE_GUARD_UPSTREAM_REF,
        UI_SHELL_SOURCE_GUARD_FAMILY_SOURCE_REF,
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
            "upstream_editor_epdoc_surface_card_pass",
            upstream.overall_pass,
        ),
        (
            "upstream_next_cursor_ui_shell_source_guard",
            upstream.next_cursor == "ui_shell_source_guard_release_blocker_card",
        ),
        (
            "ui_shell_source_guard_family_bound",
            witness.card.family_id == "ui_shell_source_guard",
        ),
        (
            "ui_shell_source_guard_issue_count_retained",
            witness.card.issue_count == family.issue_count && witness.card.issue_count == 14,
        ),
        (
            "source_refs_cover_ui_shell_source_guards",
            witness.metrics.source_ref_count == required_ui_shell_source_guard_source_refs().len(),
        ),
        (
            "focused_commands_cover_ui_shell_tests",
            witness.metrics.focused_command_count >= 5,
        ),
        (
            "ui_shell_invariants_bound",
            witness.metrics.invariant_count == required_ui_shell_source_guard_invariants().len(),
        ),
        (
            "app_environment_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/App/AppEnvironment.swift"),
        ),
        (
            "page_shell_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Views/Shell/PageShell.swift"),
        ),
        (
            "runtime_truth_settings_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Views/Settings/RuntimeTruthHealthRow.swift"),
        ),
        (
            "no_shell_surface_as_capability_proof",
            !witness.card.shell_surface_as_capability_proof,
        ),
        (
            "settings_do_not_unlock_gated_capability",
            !witness.card.settings_unlocks_gated_capability,
        ),
        (
            "mini_chat_not_agent_route_proof",
            !witness.card.mini_chat_as_agent_route_proof,
        ),
        (
            "runtime_lanes_do_not_mutate_routes",
            !witness.card.runtime_lanes_mutate_routes,
        ),
        (
            "answer_packet_caveat_visible",
            !witness.card.answer_packet_caveat_hidden,
        ),
        (
            "mas_pro_boundaries_not_collapsed",
            !witness.card.mas_pro_boundary_collapsed,
        ),
        (
            "unsupported_modes_not_marked_live",
            !witness.card.unsupported_mode_marked_live,
        ),
        (
            "app_environment_drift_not_ignored",
            !witness.card.app_environment_drift_ignored,
        ),
        (
            "hidden_agent_overlay_not_mounted",
            !witness.card.hidden_agent_overlay_mounted,
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
            "no_shell_model_bytes_or_provider_calls",
            witness.metrics.shell_bytes_loaded == 0
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
            witness.next_cursor == UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
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
            "ui_shell_source_guard_issue_count",
            witness.card.issue_count,
            14,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_ui_shell_source_guard_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            5,
            "commands",
        ),
        (
            "ui_shell_invariant_count",
            witness.metrics.invariant_count as u64,
            required_ui_shell_source_guard_invariants().len() as u64,
            "invariants",
        ),
        (
            "shell_bytes_loaded_total",
            witness.metrics.shell_bytes_loaded,
            0,
            "bytes",
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
        "ui_shell_source_guard_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "ui_shell_source_guard_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "ui_shell_source_guard_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "ui_shell_source_guard_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "ui_shell_source_guard_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("ui_shell_source_guard_card".to_string(), true);

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
            value: serde_json::json!(UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    );

    for axis in UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_AXES {
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
        notes: "metadata-only F-UiShellSourceGuard-ReleaseBlockerCard: consumes editor/EPDoc blocker and release-audit family source card, binds ui_shell_source_guard issue count 14 to AppEnvironment, AppBootstrap, RootView, UtilityWindowManager, PageShell, ToastOverlay, Settings runtime truth, AnswerPacket health, Mini Chat, and focused shell/settings/source-guard tests, and rejects shell surface capability proof, settings unlocking gated capability, Mini Chat route proof, runtime-lane route mutation, hidden AnswerPacket caveats, MAS/Pro collapse, unsupported modes marked live, AppEnvironment drift, hidden agent overlays, L2/L3/product green, provider calls, byte leaks, and live dense-70B claims.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:ui-shell-source-guard-release-blocker-card:upstream-parser
// Plane: Verification.
// Residency: metadata-only; reads artifact JSON only.
#[derive(Debug)]
struct UpstreamEditorEpdocSurfaceCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamEditorEpdocSurfaceCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamEditorEpdocSurfaceCard {
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

// UAS: uas:ui-shell-source-guard-release-blocker-card:family-parser
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
    let family = cards
        .iter()
        .find(|card| {
            card.get("family_id").and_then(serde_json::Value::as_str)
                == Some("ui_shell_source_guard")
        })
        .ok_or("missing ui_shell_source_guard family")?;
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

fn red_fixture_results(witness: &UiShellSourceGuardReleaseBlockerWitness) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "ui_shell_source_guard_release_blocker_card",
            "ui_shell_source_guard",
            14,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "editor_epdoc_surface_release_blocker_card",
            "ui_shell_source_guard",
            14,
        ),
        (
            "wrong_family_rejected",
            true,
            "ui_shell_source_guard_release_blocker_card",
            "editor_epdoc_surface",
            14,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "ui_shell_source_guard_release_blocker_card",
            "ui_shell_source_guard",
            0,
        ),
    ] {
        let rejected = UiShellSourceGuardReleaseBlockerWitness::new(
            UI_SHELL_SOURCE_GUARD_UPSTREAM_REF,
            UI_SHELL_SOURCE_GUARD_FAMILY_SOURCE_REF,
            upstream_pass,
            cursor,
            family,
            issues,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add_card = |id: &str,
                    mutate: fn(&mut agent_core::uas::UiShellSourceGuardReleaseBlockerCard),
                    results: &mut Vec<(String, bool)>| {
        let mut card = witness.card.clone();
        mutate(&mut card);
        results.push((id.to_string(), card.validate().is_err()));
    };
    add_card(
        "missing_app_environment_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/App/AppEnvironment.swift")
        },
        &mut results,
    );
    add_card(
        "missing_page_shell_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Views/Shell/PageShell.swift")
        },
        &mut results,
    );
    add_card(
        "missing_runtime_truth_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Views/Settings/RuntimeTruthHealthRow.swift")
        },
        &mut results,
    );
    add_card(
        "missing_app_environment_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "app_environment_is_single_shell_injection_source")
        },
        &mut results,
    );
    add_card(
        "missing_answer_packet_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "answer_packet_health_row_remains_caveated")
        },
        &mut results,
    );
    add_card(
        "shell_surface_capability_proof_rejected",
        |card| card.shell_surface_as_capability_proof = true,
        &mut results,
    );
    add_card(
        "settings_unlock_gated_capability_rejected",
        |card| card.settings_unlocks_gated_capability = true,
        &mut results,
    );
    add_card(
        "mini_chat_route_proof_rejected",
        |card| card.mini_chat_as_agent_route_proof = true,
        &mut results,
    );
    add_card(
        "runtime_lane_route_mutation_rejected",
        |card| card.runtime_lanes_mutate_routes = true,
        &mut results,
    );
    add_card(
        "answer_packet_caveat_hidden_rejected",
        |card| card.answer_packet_caveat_hidden = true,
        &mut results,
    );
    add_card(
        "mas_pro_boundary_collapse_rejected",
        |card| card.mas_pro_boundary_collapsed = true,
        &mut results,
    );
    add_card(
        "unsupported_mode_live_rejected",
        |card| card.unsupported_mode_marked_live = true,
        &mut results,
    );
    add_card(
        "app_environment_drift_rejected",
        |card| card.app_environment_drift_ignored = true,
        &mut results,
    );
    add_card(
        "hidden_agent_overlay_rejected",
        |card| card.hidden_agent_overlay_mounted = true,
        &mut results,
    );
    add_card(
        "combined_shell_authority_rejected",
        |card| {
            card.shell_surface_as_capability_proof = true;
            card.settings_unlocks_gated_capability = true;
            card.mini_chat_as_agent_route_proof = true;
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
        "shell_byte_leak_rejected",
        |card| card.shell_bytes_loaded = 1,
        &mut results,
    );
    add_card(
        "model_runtime_byte_leak_rejected",
        |card| card.model_runtime_bytes_loaded = 1,
        &mut results,
    );
    add_card(
        "provider_call_leak_rejected",
        |card| card.provider_calls_made = 1,
        &mut results,
    );
    results
}
