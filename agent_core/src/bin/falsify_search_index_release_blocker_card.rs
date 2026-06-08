//! `falsify_search_index_release_blocker_card`.
//!
//! Metadata-only witness that binds retained search-index blockers to exact
//! SearchIndex/RRF/readable-block/query-runtime freshness surfaces before
//! Eidos, TurboVec, Gemma QAT replay, KV/cache reuse, or large-model routes can
//! treat search output as evidence.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::SEARCH_INDEX_RELEASE_BLOCKER_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_search_index_invariants, required_search_index_source_refs,
    SearchIndexReleaseBlockerWitness, SEARCH_INDEX_FAMILY_SOURCE_REF,
    SEARCH_INDEX_RELEASE_BLOCKER_CARD_NEXT_CURSOR, SEARCH_INDEX_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-SearchIndex-ReleaseBlockerCard";
const FIXTURE_ID: &str = "search_index_release_blocker_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_search_index_release_blocker_card.sh";
const RESULT: &str = "artifacts/falsifiers/search_index_release_blocker_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/body_read_checksum_release_blocker_card/result.json";
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
        artifact.measurements["search_index_issue_count"].value,
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
    let witness = SearchIndexReleaseBlockerWitness::new(
        SEARCH_INDEX_UPSTREAM_REF,
        SEARCH_INDEX_FAMILY_SOURCE_REF,
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
        ("upstream_body_read_card_pass", upstream.overall_pass),
        (
            "upstream_next_cursor_search_index",
            upstream.next_cursor == "search_index_release_blocker_card",
        ),
        (
            "search_index_family_bound",
            witness.card.family_id == "search_index",
        ),
        (
            "search_index_issue_count_retained",
            witness.card.issue_count == family.issue_count && witness.card.issue_count == 1,
        ),
        (
            "source_refs_cover_search_stack",
            witness.metrics.source_ref_count == required_search_index_source_refs().len(),
        ),
        (
            "focused_commands_cover_search_tests",
            witness.metrics.focused_command_count >= 6,
        ),
        (
            "search_invariants_bound",
            witness.metrics.invariant_count == required_search_index_invariants().len(),
        ),
        (
            "search_index_service_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Sync/SearchIndexService.swift"),
        ),
        (
            "rrf_fusion_query_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Sync/RRFFusionQuery.swift"),
        ),
        (
            "query_runtime_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Engine/QueryRuntime.swift"),
        ),
        (
            "graph_evidence_sources_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Graph/GraphState.swift")
                && witness
                    .card
                    .source_refs
                    .iter()
                    .any(|value| value == "Epistemos/Graph/GraphStore.swift"),
        ),
        (
            "rrf_design_doc_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "docs/RRF_FUSION_DESIGN.md"),
        ),
        (
            "retrieval_lanes_cover_search_eidos_turbovec",
            witness.metrics.retrieval_lane_count == 7,
        ),
        (
            "rank_policies_cover_rrf_bm25_recency_scope",
            witness.metrics.rank_policy_count == 5,
        ),
        (
            "authority_policy_evidence_only",
            matches!(
                witness.card.authority_policy,
                agent_core::uas::SearchAuthorityPolicy::EvidenceOnly
            ),
        ),
        (
            "fts_trigger_rebuild_and_parser_fallback_required",
            witness.card.external_content_fts_trigger_required
                && witness.card.external_content_rebuild_fallback_required
                && witness.card.query_parser_fallback_required,
        ),
        (
            "rrf_bm25_recency_and_vault_scope_required",
            witness.card.rrf_k_parity_required
                && witness.card.bm25_rank_convention_required
                && witness.card.recency_half_life_policy_required
                && witness.card.vault_scope_filter_required,
        ),
        (
            "graph_evidence_digest_required",
            witness.card.graph_evidence_digest_required,
        ),
        (
            "large_model_replay_dependencies_bound",
            witness.card.turbovec_allowlist_before_rank_required
                && witness.card.gemma_qat_replay_search_freshness_required
                && witness.card.kv_cache_lineage_salt_required,
        ),
        (
            "no_raw_query_body_or_snippet",
            witness.card.no_raw_query_in_artifact
                && witness.card.no_raw_body_in_artifact
                && witness.card.no_raw_snippet_in_artifact,
        ),
        (
            "no_hidden_chain_search_eidos_turbovec",
            witness.card.no_hidden_chain
                && witness.card.no_hidden_search_authority
                && witness.card.no_hidden_eidos_authority
                && witness.card.no_hidden_turbovec_authority,
        ),
        ("no_provider_call", witness.card.no_provider_call),
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
            "zero_db_body_snippet_model_cache_provider_bytes",
            witness.metrics.db_bytes_opened == 0
                && witness.metrics.body_bytes_read == 0
                && witness.metrics.snippet_bytes_embedded == 0
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
            witness.next_cursor == SEARCH_INDEX_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
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
            "search_index_issue_count",
            witness.card.issue_count,
            1,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_search_index_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            6,
            "commands",
        ),
        (
            "search_invariant_count",
            witness.metrics.invariant_count as u64,
            required_search_index_invariants().len() as u64,
            "invariants",
        ),
        (
            "retrieval_lane_count",
            witness.metrics.retrieval_lane_count as u64,
            7,
            "lanes",
        ),
        (
            "rank_policy_count",
            witness.metrics.rank_policy_count as u64,
            5,
            "policies",
        ),
        (
            "db_bytes_opened_total",
            witness.metrics.db_bytes_opened,
            0,
            "bytes",
        ),
        (
            "body_bytes_read_total",
            witness.metrics.body_bytes_read,
            0,
            "bytes",
        ),
        (
            "snippet_bytes_embedded_total",
            witness.metrics.snippet_bytes_embedded,
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
        "search_index_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "search_index_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "search_index_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "search_index_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "search_index_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("search_index_card".to_string(), true);

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
            value: serde_json::json!(SEARCH_INDEX_RELEASE_BLOCKER_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == SEARCH_INDEX_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    );

    for axis in SEARCH_INDEX_RELEASE_BLOCKER_CARD_AXES {
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
        notes: "metadata-only F-SearchIndex-ReleaseBlockerCard: consumes body-read checksum freshness and release-audit search_index family, binds exact SearchIndex/RRF/readable-block/query-runtime/graph source refs, rejects stale search/rank/privacy/promotion/byte fixtures, opens zero DB/body/snippet/model/cache/provider bytes, and makes no L2/L3/product claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Debug)]
// UAS: uas:search-index-release-blocker-card:upstream-body-read-card
// Plane: Verification.
// Residency: metadata-only upstream witness summary; no body/search bytes opened.
struct UpstreamBodyReadCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamBodyReadCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamBodyReadCard {
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
// UAS: uas:search-index-release-blocker-card:failure-family-source-card
// Plane: Verification.
// Residency: metadata-only release-audit family summary; no search bytes opened.
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
            card.get("family_id").and_then(serde_json::Value::as_str) == Some("search_index")
        })
        .ok_or("missing search_index family")?;
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

fn red_fixture_results(witness: &SearchIndexReleaseBlockerWitness) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "search_index_release_blocker_card",
            "search_index",
            1,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "body_read_checksum_release_blocker_card",
            "search_index",
            1,
        ),
        (
            "wrong_family_rejected",
            true,
            "search_index_release_blocker_card",
            "body_read_checksum",
            1,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "search_index_release_blocker_card",
            "search_index",
            0,
        ),
    ] {
        let rejected = SearchIndexReleaseBlockerWitness::new(
            SEARCH_INDEX_UPSTREAM_REF,
            SEARCH_INDEX_FAMILY_SOURCE_REF,
            upstream_pass,
            cursor,
            family,
            issues,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add_card = |id: &str,
                    mutate: fn(&mut agent_core::uas::SearchIndexReleaseBlockerCard),
                    results: &mut Vec<(String, bool)>| {
        let mut card = witness.card.clone();
        mutate(&mut card);
        results.push((id.to_string(), card.validate().is_err()));
    };

    add_card(
        "missing_search_index_service_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Sync/SearchIndexService.swift")
        },
        &mut results,
    );
    add_card(
        "missing_rrf_source_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Sync/RRFFusionQuery.swift")
        },
        &mut results,
    );
    add_card(
        "missing_query_runtime_ref_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Engine/QueryRuntime.swift")
        },
        &mut results,
    );
    add_card(
        "source_refs_duplicate_rejected",
        |card| {
            card.source_refs
                .push("Epistemos/Sync/SearchIndexService.swift".to_string())
        },
        &mut results,
    );
    add_card(
        "invariant_missing_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "rrf_k_parity_required")
        },
        &mut results,
    );
    add_card(
        "focused_command_too_broad_rejected",
        |card| card.focused_commands[0] = "xcodebuild test EpistemosTests".to_string(),
        &mut results,
    );
    add_card(
        "fts_trigger_missing_rejected",
        |card| card.external_content_fts_trigger_required = false,
        &mut results,
    );
    add_card(
        "query_parser_fallback_missing_rejected",
        |card| card.query_parser_fallback_required = false,
        &mut results,
    );
    add_card(
        "rrf_k_parity_missing_rejected",
        |card| card.rrf_k_parity_required = false,
        &mut results,
    );
    add_card(
        "bm25_rank_convention_missing_rejected",
        |card| card.bm25_rank_convention_required = false,
        &mut results,
    );
    add_card(
        "vault_scope_filter_missing_rejected",
        |card| card.vault_scope_filter_required = false,
        &mut results,
    );
    add_card(
        "turbovec_allowlist_missing_rejected",
        |card| card.turbovec_allowlist_before_rank_required = false,
        &mut results,
    );
    add_card(
        "gemma_qat_search_freshness_missing_rejected",
        |card| card.gemma_qat_replay_search_freshness_required = false,
        &mut results,
    );
    add_card(
        "kv_cache_lineage_salt_missing_rejected",
        |card| card.kv_cache_lineage_salt_required = false,
        &mut results,
    );
    add_card(
        "raw_query_allowed_rejected",
        |card| card.no_raw_query_in_artifact = false,
        &mut results,
    );
    add_card(
        "raw_snippet_allowed_rejected",
        |card| card.no_raw_snippet_in_artifact = false,
        &mut results,
    );
    add_card(
        "hidden_eidos_authority_allowed_rejected",
        |card| card.no_hidden_eidos_authority = false,
        &mut results,
    );
    add_card(
        "hidden_turbovec_authority_allowed_rejected",
        |card| card.no_hidden_turbovec_authority = false,
        &mut results,
    );
    add_card(
        "db_bytes_opened_nonzero_rejected",
        |card| card.db_bytes_opened = 1,
        &mut results,
    );
    add_card(
        "snippet_bytes_embedded_nonzero_rejected",
        |card| card.snippet_bytes_embedded = 1,
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
        let witness = SearchIndexReleaseBlockerWitness::new(
            SEARCH_INDEX_UPSTREAM_REF,
            SEARCH_INDEX_FAMILY_SOURCE_REF,
            true,
            "search_index_release_blocker_card",
            "search_index",
            1,
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
