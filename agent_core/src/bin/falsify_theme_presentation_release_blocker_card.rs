//! `falsify_theme_presentation_release_blocker_card`.
//!
//! Metadata-only witness that binds the retained theme/presentation release
//! blockers to exact visual proof surfaces without granting route, runtime, or
//! product capability authority.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::THEME_PRESENTATION_RELEASE_BLOCKER_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_theme_presentation_invariants, required_theme_presentation_source_refs,
    ThemePresentationReleaseBlockerWitness, THEME_PRESENTATION_FAMILY_SOURCE_REF,
    THEME_PRESENTATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR, THEME_PRESENTATION_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-ThemePresentation-ReleaseBlockerCard";
const FIXTURE_ID: &str = "theme_presentation_release_blocker_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_theme_presentation_release_blocker_card.sh";
const RESULT: &str = "artifacts/falsifiers/theme_presentation_release_blocker_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/research_tool_catalog_no_hidden_authority/result.json";
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
        artifact.measurements["theme_presentation_issue_count"].value,
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
    let witness = ThemePresentationReleaseBlockerWitness::new(
        THEME_PRESENTATION_UPSTREAM_REF,
        THEME_PRESENTATION_FAMILY_SOURCE_REF,
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
        ("upstream_research_tool_card_pass", upstream.overall_pass),
        (
            "upstream_next_cursor_theme_presentation",
            upstream.next_cursor == "theme_presentation_release_blocker_card",
        ),
        (
            "theme_presentation_family_bound",
            witness.card.family_id == "theme_presentation",
        ),
        (
            "theme_presentation_issue_count_retained",
            witness.card.issue_count == family.issue_count && witness.card.issue_count == 19,
        ),
        (
            "source_refs_cover_theme_presentation_surfaces",
            witness.metrics.source_ref_count == required_theme_presentation_source_refs().len(),
        ),
        (
            "focused_commands_cover_theme_presentation_tests",
            witness.metrics.focused_command_count >= 4,
        ),
        (
            "theme_presentation_invariants_bound",
            witness.metrics.invariant_count == required_theme_presentation_invariants().len(),
        ),
        (
            "epistemos_theme_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Theme/EpistemosTheme.swift"),
        ),
        (
            "chat_presentation_tests_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "EpistemosTests/ChatPresentationTests.swift"),
        ),
        (
            "theme_pair_tests_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "EpistemosTests/ThemePairTests.swift"),
        ),
        (
            "no_presentation_as_capability_proof",
            !witness.card.presentation_as_capability_proof,
        ),
        (
            "no_theme_tokens_as_runtime_route",
            !witness.card.theme_tokens_select_runtime_route,
        ),
        (
            "answer_packet_caveats_visible",
            !witness.card.answer_packet_caveat_hidden,
        ),
        (
            "mas_pro_visual_copy_honest",
            !witness.card.mas_pro_copy_overclaims_capability,
        ),
        (
            "animation_stability_gates_required",
            !witness.card.repeat_forever_animation_claimed
                && !witness.card.window_occlusion_gate_missing
                && !witness.card.reduce_motion_gate_missing,
        ),
        (
            "theme_switch_not_runtime_handle_mutation",
            !witness.card.theme_switch_recreates_runtime_handles,
        ),
        (
            "settings_do_not_unlock_gated_capability",
            !witness.card.settings_unlocks_gated_capability,
        ),
        (
            "no_hidden_tool_payload_visibility",
            !witness.card.hidden_tool_payload_visible,
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
            "no_runtime_bytes_or_provider_calls",
            witness.metrics.model_runtime_bytes_loaded == 0
                && witness.metrics.product_runtime_bytes_loaded == 0
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
            witness.next_cursor == THEME_PRESENTATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
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
            "theme_presentation_issue_count",
            witness.card.issue_count,
            19,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_theme_presentation_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            4,
            "commands",
        ),
        (
            "theme_presentation_invariant_count",
            witness.metrics.invariant_count as u64,
            required_theme_presentation_invariants().len() as u64,
            "invariants",
        ),
        (
            "model_runtime_bytes_loaded_total",
            witness.metrics.model_runtime_bytes_loaded,
            0,
            "bytes",
        ),
        (
            "product_runtime_bytes_loaded_total",
            witness.metrics.product_runtime_bytes_loaded,
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
        "theme_presentation_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "theme_presentation_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "theme_presentation_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "theme_presentation_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "theme_presentation_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("theme_presentation_card".to_string(), true);

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
            value: serde_json::json!(THEME_PRESENTATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == THEME_PRESENTATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    );

    for axis in THEME_PRESENTATION_RELEASE_BLOCKER_CARD_AXES {
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
        notes: "metadata-only F-ThemePresentation-ReleaseBlockerCard: consumes the research-tool catalog blocker and release-audit family source card, binds theme_presentation issue count 19 to exact theme/chat/settings/landing source refs, and rejects visual presentation as route authority, capability proof, MAS/Pro overclaim, hidden tool payload visibility, unstable animation gates, L2/L3/product green, provider calls, and live dense-70B claims.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:theme-presentation-release-blocker-card:upstream-parser
// Plane: Verification.
// Residency: metadata-only; reads artifact JSON only.
#[derive(Debug)]
struct UpstreamResearchToolCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamResearchToolCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamResearchToolCard {
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

// UAS: uas:theme-presentation-release-blocker-card:family-parser
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
            card.get("family_id").and_then(serde_json::Value::as_str) == Some("theme_presentation")
        })
        .ok_or("missing theme_presentation family")?;
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

fn red_fixture_results(witness: &ThemePresentationReleaseBlockerWitness) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "theme_presentation_release_blocker_card",
            "theme_presentation",
            19,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "research_tool_catalog_no_hidden_authority",
            "theme_presentation",
            19,
        ),
        (
            "wrong_family_rejected",
            true,
            "theme_presentation_release_blocker_card",
            "research_tool_catalog",
            16,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "theme_presentation_release_blocker_card",
            "theme_presentation",
            0,
        ),
    ] {
        let rejected = ThemePresentationReleaseBlockerWitness::new(
            THEME_PRESENTATION_UPSTREAM_REF,
            THEME_PRESENTATION_FAMILY_SOURCE_REF,
            upstream_pass,
            cursor,
            family,
            issues,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add_card = |id: &str,
                    mutate: fn(&mut agent_core::uas::ThemePresentationReleaseBlockerCard),
                    results: &mut Vec<(String, bool)>| {
        let mut card = witness.card.clone();
        mutate(&mut card);
        results.push((id.to_string(), card.validate().is_err()));
    };
    add_card(
        "missing_epistemos_theme_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Theme/EpistemosTheme.swift")
        },
        &mut results,
    );
    add_card(
        "missing_chat_presentation_tests_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "EpistemosTests/ChatPresentationTests.swift")
        },
        &mut results,
    );
    add_card(
        "missing_visible_proof_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "presentation_surfaces_are_visible_proof_only")
        },
        &mut results,
    );
    add_card(
        "missing_animation_gate_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "reduce_motion_and_window_occlusion_gate_animation")
        },
        &mut results,
    );
    add_card(
        "presentation_capability_proof_rejected",
        |card| card.presentation_as_capability_proof = true,
        &mut results,
    );
    add_card(
        "theme_runtime_route_rejected",
        |card| card.theme_tokens_select_runtime_route = true,
        &mut results,
    );
    add_card(
        "answer_packet_caveat_hidden_rejected",
        |card| card.answer_packet_caveat_hidden = true,
        &mut results,
    );
    add_card(
        "mas_pro_copy_overclaim_rejected",
        |card| card.mas_pro_copy_overclaims_capability = true,
        &mut results,
    );
    add_card(
        "repeat_forever_animation_rejected",
        |card| card.repeat_forever_animation_claimed = true,
        &mut results,
    );
    add_card(
        "missing_window_occlusion_gate_rejected",
        |card| card.window_occlusion_gate_missing = true,
        &mut results,
    );
    add_card(
        "missing_reduce_motion_gate_rejected",
        |card| card.reduce_motion_gate_missing = true,
        &mut results,
    );
    add_card(
        "theme_runtime_handle_mutation_rejected",
        |card| card.theme_switch_recreates_runtime_handles = true,
        &mut results,
    );
    add_card(
        "settings_unlocks_gated_capability_rejected",
        |card| card.settings_unlocks_gated_capability = true,
        &mut results,
    );
    add_card(
        "hidden_tool_payload_visible_rejected",
        |card| card.hidden_tool_payload_visible = true,
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
    add_card(
        "product_runtime_byte_leak_rejected",
        |card| card.product_runtime_bytes_loaded = 1,
        &mut results,
    );
    add_card(
        "provider_call_leak_rejected",
        |card| card.provider_calls_made = 1,
        &mut results,
    );

    results
}
