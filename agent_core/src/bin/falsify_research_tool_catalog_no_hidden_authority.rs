//! `falsify_research_tool_catalog_no_hidden_authority`.
//!
//! Metadata-only witness that binds the retained research-tool catalog release
//! blockers to exact tool registry surfaces without granting hidden route,
//! cloud, or product authority.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_research_tool_catalog_invariants, required_research_tool_catalog_source_refs,
    ResearchToolCatalogNoHiddenAuthorityWitness, RESEARCH_TOOL_CATALOG_FAMILY_SOURCE_REF,
    RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_NEXT_CURSOR, RESEARCH_TOOL_CATALOG_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-ResearchToolCatalog-NoHiddenAuthority";
const FIXTURE_ID: &str = "research_tool_catalog_no_hidden_authority_v1";
const COMMAND: &str = "Tools/falsifiers/f_research_tool_catalog_no_hidden_authority.sh";
const RESULT: &str = "artifacts/falsifiers/research_tool_catalog_no_hidden_authority/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/graph_filter_visibility_release_blocker_card/result.json";
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
        artifact.measurements["research_tool_issue_count"].value,
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
    let witness = ResearchToolCatalogNoHiddenAuthorityWitness::new(
        RESEARCH_TOOL_CATALOG_UPSTREAM_REF,
        RESEARCH_TOOL_CATALOG_FAMILY_SOURCE_REF,
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
        ("upstream_graph_filter_card_pass", upstream.overall_pass),
        (
            "upstream_next_cursor_research_tool_catalog",
            upstream.next_cursor == "research_tool_catalog_no_hidden_authority",
        ),
        (
            "research_tool_family_bound",
            witness.card.family_id == "research_tool_catalog",
        ),
        (
            "research_tool_issue_count_retained",
            witness.card.issue_count == family.issue_count && witness.card.issue_count == 16,
        ),
        (
            "source_refs_cover_research_tool_surfaces",
            witness.metrics.source_ref_count == required_research_tool_catalog_source_refs().len(),
        ),
        (
            "focused_commands_cover_research_tool_tests",
            witness.metrics.focused_command_count >= 3,
        ),
        (
            "research_tool_invariants_bound",
            witness.metrics.invariant_count == required_research_tool_catalog_invariants().len(),
        ),
        (
            "omega_tool_registry_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Omega/MCPBridge.swift"),
        ),
        (
            "tool_tier_bridge_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Bridge/ToolTierBridge.swift"),
        ),
        (
            "rust_tool_registry_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "agent_core/src/tools/registry.rs"),
        ),
        (
            "research_mode_tests_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "EpistemosTests/ResearchModeTests.swift"),
        ),
        (
            "no_research_catalog_as_route_authority",
            !witness.card.research_catalog_as_route_authority,
        ),
        (
            "no_hidden_research_tool_authority",
            !witness.card.hidden_research_tool_authority,
        ),
        (
            "no_destructive_or_unconfirmed_research_tools",
            !witness.card.destructive_research_tool_claimed
                && !witness.card.unconfirmed_mutating_research_tool_claimed,
        ),
        (
            "no_alias_authority_expansion",
            !witness.card.alias_expands_authority,
        ),
        (
            "no_chat_lite_agent_tool_inheritance",
            !witness.card.chat_lite_inherits_agent_tools,
        ),
        (
            "no_chat_pro_full_agent_inheritance",
            !witness.card.chat_pro_inherits_full_agent_surface,
        ),
        (
            "catalog_export_not_runtime_proof",
            !witness.card.catalog_export_as_runtime_proof,
        ),
        (
            "research_complexity_gate_not_route_authority",
            !witness.card.research_complexity_gate_as_route_authority,
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
                && witness.metrics.tool_runtime_bytes_loaded == 0
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
            witness.next_cursor == RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_NEXT_CURSOR,
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
            "research_tool_issue_count",
            witness.card.issue_count,
            16,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_research_tool_catalog_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            3,
            "commands",
        ),
        (
            "research_tool_invariant_count",
            witness.metrics.invariant_count as u64,
            required_research_tool_catalog_invariants().len() as u64,
            "invariants",
        ),
        (
            "model_runtime_bytes_loaded_total",
            witness.metrics.model_runtime_bytes_loaded,
            0,
            "bytes",
        ),
        (
            "tool_runtime_bytes_loaded_total",
            witness.metrics.tool_runtime_bytes_loaded,
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
        "research_tool_catalog_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "research_tool_catalog_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "research_tool_catalog_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "research_tool_catalog_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "research_tool_catalog_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("research_tool_catalog_card".to_string(), true);

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
            value: serde_json::json!(RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_NEXT_CURSOR,
    );

    for axis in RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_AXES {
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
        notes: "metadata-only F-ResearchToolCatalog-NoHiddenAuthority: consumes the graph-filter blocker and release-audit family source card, binds research_tool_catalog issue count 16 to exact OmegaToolRegistry, ToolTierBridge, ResearchOrchestrator, ResearchComplexityGate, AgentAuthority, Rust ToolRegistry, and ResearchModeTests refs, and rejects research catalogs as hidden route authority, destructive or unconfirmed research tool claims, alias authority expansion, ChatLite/ChatPro tool-surface inheritance, runtime proof claims, provider calls, L2/L3/product green, and live dense-70B claims.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:research-tool-catalog-no-hidden-authority:upstream-parser
// Plane: Verification.
// Residency: metadata-only; reads artifact JSON only.
#[derive(Debug)]
struct UpstreamGraphFilterCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamGraphFilterCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamGraphFilterCard {
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

// UAS: uas:research-tool-catalog-no-hidden-authority:family-parser
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
    let research_tool = cards
        .iter()
        .find(|card| {
            card.get("family_id").and_then(serde_json::Value::as_str)
                == Some("research_tool_catalog")
        })
        .ok_or("missing research_tool_catalog family")?;
    Ok(FamilySourceCard {
        family_id: research_tool
            .get("family_id")
            .and_then(serde_json::Value::as_str)
            .unwrap_or_default()
            .to_string(),
        issue_count: research_tool
            .get("issue_count")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0),
    })
}

fn red_fixture_results(
    witness: &ResearchToolCatalogNoHiddenAuthorityWitness,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "research_tool_catalog_no_hidden_authority",
            "research_tool_catalog",
            16,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "graph_filter_visibility_release_blocker_card",
            "research_tool_catalog",
            16,
        ),
        (
            "wrong_family_rejected",
            true,
            "research_tool_catalog_no_hidden_authority",
            "graph_filter_visibility",
            34,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "research_tool_catalog_no_hidden_authority",
            "research_tool_catalog",
            0,
        ),
    ] {
        let rejected = ResearchToolCatalogNoHiddenAuthorityWitness::new(
            RESEARCH_TOOL_CATALOG_UPSTREAM_REF,
            RESEARCH_TOOL_CATALOG_FAMILY_SOURCE_REF,
            upstream_pass,
            cursor,
            family,
            issues,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add_card = |id: &str,
                    mutate: fn(&mut agent_core::uas::ResearchToolCatalogNoHiddenAuthorityCard),
                    results: &mut Vec<(String, bool)>| {
        let mut card = witness.card.clone();
        mutate(&mut card);
        results.push((id.to_string(), card.validate().is_err()));
    };
    add_card(
        "missing_omega_tool_registry_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Omega/MCPBridge.swift")
        },
        &mut results,
    );
    add_card(
        "missing_tool_tier_bridge_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Bridge/ToolTierBridge.swift")
        },
        &mut results,
    );
    add_card(
        "missing_research_tools_explicit_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "seven_research_tools_are_explicit_catalog_entries")
        },
        &mut results,
    );
    add_card(
        "missing_agent_authority_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "agent_authority_policy_must_admit_each_tool_use")
        },
        &mut results,
    );
    add_card(
        "research_catalog_route_authority_rejected",
        |card| card.research_catalog_as_route_authority = true,
        &mut results,
    );
    add_card(
        "hidden_research_tool_authority_rejected",
        |card| card.hidden_research_tool_authority = true,
        &mut results,
    );
    add_card(
        "destructive_research_tool_claim_rejected",
        |card| card.destructive_research_tool_claimed = true,
        &mut results,
    );
    add_card(
        "unconfirmed_mutating_research_tool_rejected",
        |card| card.unconfirmed_mutating_research_tool_claimed = true,
        &mut results,
    );
    add_card(
        "alias_authority_expansion_rejected",
        |card| card.alias_expands_authority = true,
        &mut results,
    );
    add_card(
        "chat_lite_agent_tool_inheritance_rejected",
        |card| card.chat_lite_inherits_agent_tools = true,
        &mut results,
    );
    add_card(
        "chat_pro_full_agent_inheritance_rejected",
        |card| card.chat_pro_inherits_full_agent_surface = true,
        &mut results,
    );
    add_card(
        "catalog_export_runtime_proof_rejected",
        |card| card.catalog_export_as_runtime_proof = true,
        &mut results,
    );
    add_card(
        "research_complexity_gate_route_authority_rejected",
        |card| card.research_complexity_gate_as_route_authority = true,
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
        "tool_runtime_byte_leak_rejected",
        |card| card.tool_runtime_bytes_loaded = 1,
        &mut results,
    );
    add_card(
        "provider_call_leak_rejected",
        |card| card.provider_calls_made = 1,
        &mut results,
    );

    results
}
