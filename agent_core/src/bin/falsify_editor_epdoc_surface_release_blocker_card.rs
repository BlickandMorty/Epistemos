//! `falsify_editor_epdoc_surface_release_blocker_card`.
//!
//! Metadata-only witness that binds retained editor/EPDoc release blockers to
//! exact Prose/TextKit, EPDoc, readable-block, bridge, and test surfaces without
//! granting route, runtime, WRV, MAS, L2, L3, or product proof.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_editor_epdoc_surface_invariants, required_editor_epdoc_surface_source_refs,
    EditorEpdocSurfaceReleaseBlockerWitness, EDITOR_EPDOC_SURFACE_FAMILY_SOURCE_REF,
    EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR, EDITOR_EPDOC_SURFACE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-EditorEpdocSurface-ReleaseBlockerCard";
const FIXTURE_ID: &str = "editor_epdoc_surface_release_blocker_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_editor_epdoc_surface_release_blocker_card.sh";
const RESULT: &str = "artifacts/falsifiers/editor_epdoc_surface_release_blocker_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/distribution_project_integrity_release_blocker_card/result.json";
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
        artifact.measurements["editor_epdoc_surface_issue_count"].value,
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
    let witness = EditorEpdocSurfaceReleaseBlockerWitness::new(
        EDITOR_EPDOC_SURFACE_UPSTREAM_REF,
        EDITOR_EPDOC_SURFACE_FAMILY_SOURCE_REF,
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
            "upstream_distribution_project_integrity_card_pass",
            upstream.overall_pass,
        ),
        (
            "upstream_next_cursor_editor_epdoc_surface",
            upstream.next_cursor == "editor_epdoc_surface_release_blocker_card",
        ),
        (
            "editor_epdoc_surface_family_bound",
            witness.card.family_id == "editor_epdoc_surface",
        ),
        (
            "editor_epdoc_surface_issue_count_retained",
            witness.card.issue_count == family.issue_count && witness.card.issue_count == 14,
        ),
        (
            "source_refs_cover_editor_epdoc_surfaces",
            witness.metrics.source_ref_count == required_editor_epdoc_surface_source_refs().len(),
        ),
        (
            "focused_commands_cover_editor_epdoc_tests",
            witness.metrics.focused_command_count >= 5,
        ),
        (
            "editor_epdoc_invariants_bound",
            witness.metrics.invariant_count == required_editor_epdoc_surface_invariants().len(),
        ),
        (
            "prose_textkit_sources_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Views/Notes/ProseTextView2.swift"),
        ),
        (
            "epdoc_bridge_sources_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Engine/EpdocEditorBridge.swift"),
        ),
        (
            "readable_blocks_sources_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Sync/ReadableBlocksProjector.swift"),
        ),
        (
            "no_editor_surface_as_runtime_proof",
            !witness.card.editor_surface_as_runtime_proof,
        ),
        (
            "no_epdoc_package_as_runtime_proof",
            !witness.card.epdoc_package_as_runtime_proof,
        ),
        (
            "readable_blocks_not_route_authority",
            !witness.card.readable_blocks_as_route_authority,
        ),
        (
            "model_mutations_require_acceptance",
            !witness.card.model_mutation_without_acceptance,
        ),
        (
            "hidden_chain_tool_payload_not_editor_content",
            !witness.card.hidden_chain_rendered_as_editor_content
                && !witness.card.hidden_tool_payload_rendered_as_editor_content,
        ),
        (
            "projection_staleness_and_checksum_guarded",
            !witness.card.stale_projection_ignored && !witness.card.checksum_guard_missing,
        ),
        (
            "copilot_freeform_agent_claim_not_made",
            !witness.card.copilot_freeform_agent_claimed,
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
            "no_editor_model_bytes_or_provider_calls",
            witness.metrics.editor_bytes_loaded == 0
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
            witness.next_cursor == EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
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
            "editor_epdoc_surface_issue_count",
            witness.card.issue_count,
            14,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_editor_epdoc_surface_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            5,
            "commands",
        ),
        (
            "editor_epdoc_invariant_count",
            witness.metrics.invariant_count as u64,
            required_editor_epdoc_surface_invariants().len() as u64,
            "invariants",
        ),
        (
            "editor_bytes_loaded_total",
            witness.metrics.editor_bytes_loaded,
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
        "editor_epdoc_surface_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "editor_epdoc_surface_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "editor_epdoc_surface_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "editor_epdoc_surface_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "editor_epdoc_surface_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("editor_epdoc_surface_card".to_string(), true);

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
            value: serde_json::json!(EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    );

    for axis in EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_AXES {
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
        notes: "metadata-only F-EditorEpdocSurface-ReleaseBlockerCard: consumes distribution integrity blocker and release-audit family source card, binds editor_epdoc_surface issue count 14 to Prose/TextKit, EPDoc chrome/bridge, readable-block projection/index, js bridge, and focused tests, and rejects editor/package/readable-block runtime proof, hidden route authority, unsafe model mutation, hidden chain/tool editor content, stale projection/checksum bypass, copilot freeform-agent overclaim, L2/L3/product green, provider calls, byte leaks, and live dense-70B claims.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:editor-epdoc-surface-release-blocker-card:upstream-parser
// Plane: Verification.
// Residency: metadata-only; reads artifact JSON only.
#[derive(Debug)]
struct UpstreamDistributionProjectIntegrityCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamDistributionProjectIntegrityCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamDistributionProjectIntegrityCard {
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

// UAS: uas:editor-epdoc-surface-release-blocker-card:family-parser
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
                == Some("editor_epdoc_surface")
        })
        .ok_or("missing editor_epdoc_surface family")?;
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

fn red_fixture_results(witness: &EditorEpdocSurfaceReleaseBlockerWitness) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "editor_epdoc_surface_release_blocker_card",
            "editor_epdoc_surface",
            14,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "distribution_project_integrity_release_blocker_card",
            "editor_epdoc_surface",
            14,
        ),
        (
            "wrong_family_rejected",
            true,
            "editor_epdoc_surface_release_blocker_card",
            "distribution_project_integrity",
            18,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "editor_epdoc_surface_release_blocker_card",
            "editor_epdoc_surface",
            0,
        ),
    ] {
        let rejected = EditorEpdocSurfaceReleaseBlockerWitness::new(
            EDITOR_EPDOC_SURFACE_UPSTREAM_REF,
            EDITOR_EPDOC_SURFACE_FAMILY_SOURCE_REF,
            upstream_pass,
            cursor,
            family,
            issues,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add_card = |id: &str,
                    mutate: fn(&mut agent_core::uas::EditorEpdocSurfaceReleaseBlockerCard),
                    results: &mut Vec<(String, bool)>| {
        let mut card = witness.card.clone();
        mutate(&mut card);
        results.push((id.to_string(), card.validate().is_err()));
    };
    add_card(
        "missing_prose_textview_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Views/Notes/ProseTextView2.swift")
        },
        &mut results,
    );
    add_card(
        "missing_epdoc_bridge_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Engine/EpdocEditorBridge.swift")
        },
        &mut results,
    );
    add_card(
        "missing_readable_blocks_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Sync/ReadableBlocksProjector.swift")
        },
        &mut results,
    );
    add_card(
        "missing_undo_safe_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "prose_textkit_mutations_remain_undo_safe")
        },
        &mut results,
    );
    add_card(
        "missing_answer_packet_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "large_model_editor_claims_require_answer_packet")
        },
        &mut results,
    );
    add_card(
        "editor_surface_runtime_proof_rejected",
        |card| card.editor_surface_as_runtime_proof = true,
        &mut results,
    );
    add_card(
        "epdoc_package_runtime_proof_rejected",
        |card| card.epdoc_package_as_runtime_proof = true,
        &mut results,
    );
    add_card(
        "readable_blocks_route_authority_rejected",
        |card| card.readable_blocks_as_route_authority = true,
        &mut results,
    );
    add_card(
        "model_mutation_without_acceptance_rejected",
        |card| card.model_mutation_without_acceptance = true,
        &mut results,
    );
    add_card(
        "hidden_chain_tool_editor_content_rejected",
        |card| {
            card.hidden_chain_rendered_as_editor_content = true;
            card.hidden_tool_payload_rendered_as_editor_content = true;
        },
        &mut results,
    );
    add_card(
        "stale_projection_checksum_bypass_rejected",
        |card| {
            card.stale_projection_ignored = true;
            card.checksum_guard_missing = true;
        },
        &mut results,
    );
    add_card(
        "copilot_freeform_agent_claim_rejected",
        |card| card.copilot_freeform_agent_claimed = true,
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
        "editor_byte_leak_rejected",
        |card| card.editor_bytes_loaded = 1,
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
