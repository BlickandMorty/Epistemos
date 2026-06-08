//! `falsify_source_guard_drift_release_blocker_card`.
//!
//! Metadata-only witness that binds retained source-guard drift blockers to
//! exact Swift/Rust source-guard tests and canon parity surfaces before search,
//! Eidos, TurboVec/QAT, or large-model route evidence can inherit source claims.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_source_guard_drift_invariants, required_source_guard_drift_source_refs,
    SourceGuardDriftReleaseBlockerWitness, SOURCE_GUARD_DRIFT_FAMILY_SOURCE_REF,
    SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_NEXT_CURSOR, SOURCE_GUARD_DRIFT_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-SourceGuardDrift-ReleaseBlockerCard";
const FIXTURE_ID: &str = "source_guard_drift_release_blocker_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_source_guard_drift_release_blocker_card.sh";
const RESULT: &str = "artifacts/falsifiers/source_guard_drift_release_blocker_card/result.json";
const UPSTREAM_RESULT: &str = "artifacts/falsifiers/search_index_release_blocker_card/result.json";
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
        artifact.measurements["source_guard_drift_issue_count"].value,
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
    let witness = SourceGuardDriftReleaseBlockerWitness::new(
        SOURCE_GUARD_DRIFT_UPSTREAM_REF,
        SOURCE_GUARD_DRIFT_FAMILY_SOURCE_REF,
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

    for (name, passed) in
        [
            ("upstream_search_index_card_pass", upstream.overall_pass),
            (
                "upstream_next_cursor_source_guard_drift",
                upstream.next_cursor == "source_guard_drift_release_blocker_card",
            ),
            (
                "source_guard_drift_family_bound",
                witness.card.family_id == "source_guard_drift",
            ),
            (
                "source_guard_drift_issue_count_retained",
                witness.card.issue_count == family.issue_count && witness.card.issue_count == 3,
            ),
            (
                "source_refs_cover_source_guard_surfaces",
                witness.metrics.source_ref_count == required_source_guard_drift_source_refs().len(),
            ),
            (
                "focused_commands_cover_source_guard_tests",
                witness.metrics.focused_command_count >= 6,
            ),
            (
                "source_guard_invariants_bound",
                witness.metrics.invariant_count == required_source_guard_drift_invariants().len(),
            ),
            (
                "swift_source_guard_tests_bound",
                witness
                    .card
                    .source_refs
                    .iter()
                    .any(|value| value == "EpistemosTests/UASDeclarationSourceGuardTests.swift")
                    && witness.card.source_refs.iter().any(|value| {
                        value == "EpistemosTests/CoreMASBoundarySourceGuardTests.swift"
                    }),
            ),
            (
                "rust_source_guard_tests_bound",
                witness
                    .card
                    .source_refs
                    .iter()
                    .any(|value| value == "agent_core/tests/runtime_router_policy_source_guard.rs")
                    && witness.card.source_refs.iter().any(|value| {
                        value == "agent_core/tests/runtime_router_lane_toggle_source_guard.rs"
                    }),
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
                "canon_surfaces_bound",
                witness
                    .card
                    .source_refs
                    .iter()
                    .any(|value| value == "docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md")
                    && witness
                        .card
                        .source_refs
                        .iter()
                        .any(|value| value == "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md")
                    && witness.card.source_refs.iter().any(|value| {
                        value == "docs/fusion/DEEP_RESEARCH_BREAKTHROUGH_SYNTHESIS_2026_06_06.md"
                    }),
            ),
            (
                "drift_surfaces_cover_docs_tests_lattice",
                witness.metrics.drift_surface_count == 7,
            ),
            (
                "source_identity_and_docs_parity_required",
                witness.card.source_refs_current_sha_required
                    && witness.card.docs_code_parity_required
                    && witness.card.source_guard_tests_named,
            ),
            (
                "mas_pro_and_runtime_route_no_drift_required",
                witness.card.mas_pro_boundary_no_drift_required
                    && witness.card.runtime_route_policy_no_drift_required,
            ),
            (
                "large_model_eidos_turbovec_claims_bound",
                witness.card.large_model_claim_copy_no_drift_required
                    && witness.card.eidos_search_source_identity_required
                    && witness.card.turbovec_qat_canon_identity_required,
            ),
            (
                "model_catalog_and_answer_packet_bound",
                witness.card.model_catalog_source_card_no_drift_required
                    && witness.card.answer_packet_visibility_required,
            ),
            (
                "no_stale_doc_or_hidden_authority",
                !witness.card.stale_doc_as_authority_allowed
                    && !witness.card.hidden_cloud_or_provider_fallback_allowed
                    && !witness.card.hidden_route_authority_allowed,
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
                "zero_source_model_provider_bytes",
                witness.metrics.source_file_bytes_opened == 0
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
                witness.next_cursor == SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
            ),
        ]
    {
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
            "source_guard_drift_issue_count",
            witness.card.issue_count,
            3,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_source_guard_drift_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            6,
            "commands",
        ),
        (
            "source_guard_invariant_count",
            witness.metrics.invariant_count as u64,
            required_source_guard_drift_invariants().len() as u64,
            "invariants",
        ),
        (
            "drift_surface_count",
            witness.metrics.drift_surface_count as u64,
            7,
            "surfaces",
        ),
        (
            "source_file_bytes_opened_total",
            witness.metrics.source_file_bytes_opened,
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
        "source_guard_drift_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "source_guard_drift_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "source_guard_drift_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "source_guard_drift_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "source_guard_drift_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("source_guard_drift_card".to_string(), true);

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
            value: serde_json::json!(SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    );

    for axis in SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_AXES {
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
        notes: "metadata-only F-SourceGuardDrift-ReleaseBlockerCard: consumes search freshness and release-audit source_guard_drift family, binds source-guard tests plus canon surfaces, rejects stale-doc authority, MAS/Pro drift, hidden route/cloud authority, false product green, live dense 70B, SSD-as-RAM, and byte/provider leaks; no source files, model/runtime bytes, or provider calls are opened.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Debug)]
// UAS: uas:source-guard-drift-release-blocker-card:upstream-search-card
// Plane: Verification.
// Residency: metadata-only upstream witness summary; no source/model bytes.
struct UpstreamSearchCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamSearchCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamSearchCard {
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
// UAS: uas:source-guard-drift-release-blocker-card:failure-family-source-card
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
            card.get("family_id").and_then(serde_json::Value::as_str) == Some("source_guard_drift")
        })
        .ok_or("missing source_guard_drift family")?;
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

fn red_fixture_results(witness: &SourceGuardDriftReleaseBlockerWitness) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "source_guard_drift_release_blocker_card",
            "source_guard_drift",
            3,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "search_index_release_blocker_card",
            "source_guard_drift",
            3,
        ),
        (
            "wrong_family_rejected",
            true,
            "source_guard_drift_release_blocker_card",
            "search_index",
            3,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "source_guard_drift_release_blocker_card",
            "source_guard_drift",
            0,
        ),
    ] {
        let rejected = SourceGuardDriftReleaseBlockerWitness::new(
            SOURCE_GUARD_DRIFT_UPSTREAM_REF,
            SOURCE_GUARD_DRIFT_FAMILY_SOURCE_REF,
            upstream_pass,
            cursor,
            family,
            issues,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add_card = |id: &str,
                    mutate: fn(&mut agent_core::uas::SourceGuardDriftReleaseBlockerCard),
                    results: &mut Vec<(String, bool)>| {
        let mut card = witness.card.clone();
        mutate(&mut card);
        results.push((id.to_string(), card.validate().is_err()));
    };

    add_card(
        "missing_mas_pro_doc_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md")
        },
        &mut results,
    );
    add_card(
        "missing_swift_source_guard_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "EpistemosTests/UASDeclarationSourceGuardTests.swift")
        },
        &mut results,
    );
    add_card(
        "missing_rust_source_guard_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "agent_core/tests/runtime_router_policy_source_guard.rs")
        },
        &mut results,
    );
    add_card(
        "source_refs_duplicate_rejected",
        |card| {
            card.source_refs
                .push("docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md".to_string())
        },
        &mut results,
    );
    add_card(
        "invariant_missing_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "docs_code_parity_required")
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
        "source_refs_current_sha_missing_rejected",
        |card| card.source_refs_current_sha_required = false,
        &mut results,
    );
    add_card(
        "docs_code_parity_missing_rejected",
        |card| card.docs_code_parity_required = false,
        &mut results,
    );
    add_card(
        "mas_pro_boundary_drift_allowed_rejected",
        |card| card.mas_pro_boundary_no_drift_required = false,
        &mut results,
    );
    add_card(
        "runtime_route_policy_drift_allowed_rejected",
        |card| card.runtime_route_policy_no_drift_required = false,
        &mut results,
    );
    add_card(
        "large_model_claim_drift_allowed_rejected",
        |card| card.large_model_claim_copy_no_drift_required = false,
        &mut results,
    );
    add_card(
        "eidos_search_identity_missing_rejected",
        |card| card.eidos_search_source_identity_required = false,
        &mut results,
    );
    add_card(
        "turbovec_qat_identity_missing_rejected",
        |card| card.turbovec_qat_canon_identity_required = false,
        &mut results,
    );
    add_card(
        "answer_packet_visibility_missing_rejected",
        |card| card.answer_packet_visibility_required = false,
        &mut results,
    );
    add_card(
        "stale_doc_authority_allowed_rejected",
        |card| card.stale_doc_as_authority_allowed = true,
        &mut results,
    );
    add_card(
        "hidden_cloud_fallback_allowed_rejected",
        |card| card.hidden_cloud_or_provider_fallback_allowed = true,
        &mut results,
    );
    add_card(
        "hidden_route_authority_allowed_rejected",
        |card| card.hidden_route_authority_allowed = true,
        &mut results,
    );
    add_card(
        "source_file_bytes_opened_nonzero_rejected",
        |card| card.source_file_bytes_opened = 1,
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
        let witness = SourceGuardDriftReleaseBlockerWitness::new(
            SOURCE_GUARD_DRIFT_UPSTREAM_REF,
            SOURCE_GUARD_DRIFT_FAMILY_SOURCE_REF,
            true,
            "source_guard_drift_release_blocker_card",
            "source_guard_drift",
            3,
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
