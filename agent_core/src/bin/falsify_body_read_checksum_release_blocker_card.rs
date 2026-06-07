//! `falsify_body_read_checksum_release_blocker_card`.
//!
//! Metadata-only witness that binds retained body-read checksum blockers to
//! exact body/readable-block/editor/graph/prompt/cache freshness surfaces
//! without reading user note bytes, loading model/runtime/cache bytes, or
//! granting L2/L3/product proof.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_body_read_checksum_invariants, required_body_read_checksum_source_refs,
    BodyReadChecksumReleaseBlockerWitness, BODY_READ_CHECKSUM_FAMILY_SOURCE_REF,
    BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_NEXT_CURSOR, BODY_READ_CHECKSUM_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-BodyReadChecksum-ReleaseBlockerCard";
const FIXTURE_ID: &str = "body_read_checksum_release_blocker_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_body_read_checksum_release_blocker_card.sh";
const RESULT: &str = "artifacts/falsifiers/body_read_checksum_release_blocker_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/runtime_performance_policy_release_blocker_card/result.json";
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
        artifact.measurements["body_read_checksum_issue_count"].value,
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
    let witness = BodyReadChecksumReleaseBlockerWitness::new(
        BODY_READ_CHECKSUM_UPSTREAM_REF,
        BODY_READ_CHECKSUM_FAMILY_SOURCE_REF,
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
            "upstream_runtime_performance_card_pass",
            upstream.overall_pass,
        ),
        (
            "upstream_next_cursor_body_read_checksum",
            upstream.next_cursor == "body_read_checksum_release_blocker_card",
        ),
        (
            "body_read_checksum_family_bound",
            witness.card.family_id == "body_read_checksum",
        ),
        (
            "body_read_checksum_issue_count_retained",
            witness.card.issue_count == family.issue_count && witness.card.issue_count == 1,
        ),
        (
            "source_refs_cover_body_read_checksum",
            witness.metrics.source_ref_count == required_body_read_checksum_source_refs().len(),
        ),
        (
            "focused_commands_cover_body_read_tests",
            witness.metrics.focused_command_count >= 5,
        ),
        (
            "body_read_invariants_bound",
            witness.metrics.invariant_count == required_body_read_checksum_invariants().len(),
        ),
        (
            "sdpage_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Models/SDPage.swift"),
        ),
        (
            "note_file_storage_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Sync/NoteFileStorage.swift"),
        ),
        (
            "phase_r3_test_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "EpistemosTests/PhaseR3BodyReadParityTests.swift"),
        ),
        (
            "note_chat_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/State/NoteChatState.swift"),
        ),
        (
            "readable_blocks_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Sync/ReadableBlocksIndex.swift"),
        ),
        (
            "body_source_lanes_cover_truth_order",
            witness.metrics.source_lane_count == 7,
        ),
        (
            "projection_statuses_cover_freshness_states",
            witness.metrics.projection_status_count == 5,
        ),
        (
            "cache_reuse_denied_by_default",
            matches!(
                witness.card.cache_reuse_policy,
                agent_core::uas::CacheReusePolicy::Denied
            ),
        ),
        (
            "body_digest_fields_required",
            witness.card.body_digest_required
                && witness.card.body_digest_algorithm_label_required
                && witness.card.body_byte_count_required
                && witness.card.normalized_text_count_required,
        ),
        (
            "editor_snapshot_sequence_required_axis",
            witness.card.editor_snapshot_sequence_required,
        ),
        (
            "readable_graph_prompt_cache_digests_required",
            witness.card.readable_block_projection_digest_required
                && witness.card.graph_evidence_digest_required
                && witness.card.prompt_assembly_digest_required
                && witness.card.cache_salt_digest_required,
        ),
        (
            "managed_sidecar_and_r3_parity_required",
            witness.card.managed_sidecar_first_required
                && witness.card.blank_managed_body_authoritative
                && witness.card.r3_gateway_parity_required,
        ),
        (
            "front_matter_and_unicode_policy_required",
            witness.card.front_matter_policy_required
                && witness.card.unicode_digest_fixture_required,
        ),
        (
            "body_read_parity_not_model_quality_proof",
            !witness.card.body_read_parity_as_model_quality_proof,
        ),
        (
            "no_raw_body_prompt_or_token",
            witness.card.no_raw_body_in_artifact
                && witness.card.no_raw_prompt_in_artifact
                && witness.card.no_raw_model_token_in_artifact,
        ),
        (
            "no_hidden_chain_cache_or_provider",
            witness.card.no_hidden_chain
                && witness.card.no_hidden_cache_authority
                && witness.card.no_provider_call,
        ),
        (
            "answer_packet_caveat_visible",
            !witness.card.answer_packet_caveat_hidden,
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
            "zero_body_model_cache_provider_bytes",
            witness.metrics.body_bytes_read_total == 0
                && witness.metrics.model_runtime_bytes_loaded == 0
                && witness.metrics.cache_bytes_reused == 0
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
            witness.next_cursor == BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
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
            "body_read_checksum_issue_count",
            witness.card.issue_count,
            1,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_body_read_checksum_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            5,
            "commands",
        ),
        (
            "body_read_invariant_count",
            witness.metrics.invariant_count as u64,
            required_body_read_checksum_invariants().len() as u64,
            "invariants",
        ),
        (
            "source_lane_count",
            witness.metrics.source_lane_count as u64,
            7,
            "lanes",
        ),
        (
            "projection_status_count",
            witness.metrics.projection_status_count as u64,
            5,
            "statuses",
        ),
        (
            "body_bytes_read_total",
            witness.metrics.body_bytes_read_total,
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
            "cache_bytes_reused_total",
            witness.metrics.cache_bytes_reused,
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
        "body_read_checksum_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "body_read_checksum_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "body_read_checksum_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "body_read_checksum_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "body_read_checksum_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("body_read_checksum_card".to_string(), true);

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
            value: serde_json::json!(BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    );

    for axis in BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_AXES {
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
        notes: "metadata-only F-BodyReadChecksum-ReleaseBlockerCard: consumes runtime-performance blocker and release-audit body_read_checksum family, binds exact body/readable-block/editor/graph/prompt/cache freshness refs, rejects stale body/projection/cache/promotion/byte fixtures, opens zero user-note bytes, loads zero model/runtime/cache bytes, and makes no L2/L3/product claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Debug)]
// UAS: uas:body-read-checksum-release-blocker-card:upstream-runtime-performance-card
// Plane: Verification.
// Residency: metadata-only upstream witness summary; no runtime bytes are opened.
struct UpstreamRuntimePerformanceCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamRuntimePerformanceCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamRuntimePerformanceCard {
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
// UAS: uas:body-read-checksum-release-blocker-card:failure-family-source-card
// Plane: Verification.
// Residency: metadata-only release-audit family summary; no user body bytes are opened.
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
            card.get("family_id").and_then(serde_json::Value::as_str) == Some("body_read_checksum")
        })
        .ok_or("missing body_read_checksum family")?;
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

fn red_fixture_results(witness: &BodyReadChecksumReleaseBlockerWitness) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "body_read_checksum_release_blocker_card",
            "body_read_checksum",
            1,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "runtime_performance_policy_release_blocker_card",
            "body_read_checksum",
            1,
        ),
        (
            "wrong_family_rejected",
            true,
            "body_read_checksum_release_blocker_card",
            "runtime_performance_policy",
            1,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "body_read_checksum_release_blocker_card",
            "body_read_checksum",
            0,
        ),
    ] {
        let rejected = BodyReadChecksumReleaseBlockerWitness::new(
            BODY_READ_CHECKSUM_UPSTREAM_REF,
            BODY_READ_CHECKSUM_FAMILY_SOURCE_REF,
            upstream_pass,
            cursor,
            family,
            issues,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add_card = |id: &str,
                    mutate: fn(&mut agent_core::uas::BodyReadChecksumReleaseBlockerCard),
                    results: &mut Vec<(String, bool)>| {
        let mut card = witness.card.clone();
        mutate(&mut card);
        results.push((id.to_string(), card.validate().is_err()));
    };

    add_card(
        "missing_sdpage_source_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Models/SDPage.swift")
        },
        &mut results,
    );
    add_card(
        "missing_note_file_storage_source_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Sync/NoteFileStorage.swift")
        },
        &mut results,
    );
    add_card(
        "missing_phase_r3_test_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "EpistemosTests/PhaseR3BodyReadParityTests.swift")
        },
        &mut results,
    );
    add_card(
        "missing_note_chat_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/State/NoteChatState.swift")
        },
        &mut results,
    );
    add_card(
        "missing_readable_blocks_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Sync/ReadableBlocksIndex.swift")
        },
        &mut results,
    );
    add_card(
        "source_refs_duplicate_rejected",
        |card| {
            card.source_refs
                .push("Epistemos/Models/SDPage.swift".to_string())
        },
        &mut results,
    );
    add_card(
        "invariant_missing_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "prompt_assembly_digest_required")
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
        "managed_sidecar_first_disabled_rejected",
        |card| card.managed_sidecar_first_required = false,
        &mut results,
    );
    add_card(
        "blank_managed_body_not_authoritative_rejected",
        |card| card.blank_managed_body_authoritative = false,
        &mut results,
    );
    add_card(
        "r3_gateway_parity_disabled_rejected",
        |card| card.r3_gateway_parity_required = false,
        &mut results,
    );
    add_card(
        "front_matter_policy_missing_rejected",
        |card| card.front_matter_policy_required = false,
        &mut results,
    );
    add_card(
        "unicode_fixture_missing_rejected",
        |card| card.unicode_digest_fixture_required = false,
        &mut results,
    );
    add_card(
        "editor_snapshot_sequence_missing_rejected",
        |card| card.editor_snapshot_sequence_required = false,
        &mut results,
    );
    add_card(
        "readable_block_digest_missing_rejected",
        |card| card.readable_block_projection_digest_required = false,
        &mut results,
    );
    add_card(
        "graph_evidence_digest_missing_rejected",
        |card| card.graph_evidence_digest_required = false,
        &mut results,
    );
    add_card(
        "prompt_assembly_digest_missing_rejected",
        |card| card.prompt_assembly_digest_required = false,
        &mut results,
    );
    add_card(
        "cache_salt_digest_missing_rejected",
        |card| card.cache_salt_digest_required = false,
        &mut results,
    );
    add_card(
        "raw_body_artifact_allowed_rejected",
        |card| card.no_raw_body_in_artifact = false,
        &mut results,
    );
    add_card(
        "raw_prompt_artifact_allowed_rejected",
        |card| card.no_raw_prompt_in_artifact = false,
        &mut results,
    );
    add_card(
        "hidden_cache_authority_allowed_rejected",
        |card| card.no_hidden_cache_authority = false,
        &mut results,
    );
    add_card(
        "answer_packet_caveat_hidden_rejected",
        |card| card.answer_packet_caveat_hidden = true,
        &mut results,
    );
    add_card(
        "body_read_parity_as_model_quality_proof_rejected",
        |card| card.body_read_parity_as_model_quality_proof = true,
        &mut results,
    );
    add_card(
        "body_bytes_read_nonzero_rejected",
        |card| card.body_bytes_read = 1,
        &mut results,
    );
    add_card(
        "cache_bytes_reused_nonzero_rejected",
        |card| card.cache_bytes_reused = 1,
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

    results
}
