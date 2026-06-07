//! `falsify_agent_route_policy_large_model_no_hidden_authority`.
//!
//! Metadata-only witness that prevents large-model research/catalog rows from
//! becoming hidden agent route authority before focused release repairs pass.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_agent_route_policy_invariants, required_agent_route_policy_source_refs,
    AgentRoutePolicyLargeModelNoHiddenAuthorityWitness, AGENT_ROUTE_POLICY_FAMILY_SOURCE_REF,
    AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_NEXT_CURSOR,
    AGENT_ROUTE_POLICY_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-AgentRoutePolicy-LargeModelNoHiddenAuthority";
const FIXTURE_ID: &str = "agent_route_policy_large_model_no_hidden_authority_v1";
const COMMAND: &str = "Tools/falsifiers/f_agent_route_policy_large_model_no_hidden_authority.sh";
const RESULT: &str =
    "artifacts/falsifiers/agent_route_policy_large_model_no_hidden_authority/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/model_vault_catalog_release_blocker_card/result.json";
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
        artifact.measurements["agent_route_policy_issue_count"].value,
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
    let witness = AgentRoutePolicyLargeModelNoHiddenAuthorityWitness::new(
        AGENT_ROUTE_POLICY_UPSTREAM_REF,
        AGENT_ROUTE_POLICY_FAMILY_SOURCE_REF,
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
        ("upstream_model_vault_card_pass", upstream.overall_pass),
        (
            "upstream_next_cursor_agent_route",
            upstream.next_cursor == "agent_route_policy_large_model_no_hidden_authority",
        ),
        (
            "agent_route_family_bound",
            witness.card.family_id == "agent_route_policy",
        ),
        (
            "agent_route_issue_count_retained",
            witness.card.issue_count == family.issue_count && witness.card.issue_count == 21,
        ),
        (
            "source_refs_cover_route_surfaces",
            witness.metrics.source_ref_count == required_agent_route_policy_source_refs().len(),
        ),
        (
            "focused_commands_cover_route_tests",
            witness.metrics.focused_command_count >= 4,
        ),
        (
            "route_invariants_bound",
            witness.metrics.invariant_count == required_agent_route_policy_invariants().len(),
        ),
        (
            "runtime_router_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/LocalAgent/RuntimeRouter.swift"),
        ),
        (
            "system_g_answer_packet_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/SystemG/RealSystemGRunSeam.swift"),
        ),
        (
            "mas_forbidden_tools_invariant_bound",
            witness
                .card
                .required_invariants
                .iter()
                .any(|value| value == "mas_forbidden_tools_remain_denied"),
        ),
        (
            "large_model_runtime_proof_invariant_bound",
            witness.card.required_invariants.iter().any(|value| {
                value == "large_model_candidates_require_catalog_loader_byte_runtime_proof"
            }),
        ),
        (
            "no_hidden_route_authority",
            !witness.card.hidden_route_authority,
        ),
        (
            "no_hidden_tool_authority",
            !witness.card.hidden_tool_authority,
        ),
        (
            "no_hidden_cloud_fallback",
            !witness.card.hidden_cloud_fallback,
        ),
        (
            "no_model_vault_row_as_route_authority",
            !witness.card.model_vault_row_as_route_authority,
        ),
        (
            "no_large_model_candidate_auto_route",
            !witness.card.large_model_candidate_auto_route,
        ),
        (
            "no_patternboost_eidos_lattice_live_authority",
            !witness.card.patternboost_live_authority
                && !witness.card.eidos_live_router
                && !witness.card.lattice_live_router,
        ),
        (
            "no_mas_forbidden_tool_enabled",
            !witness.card.mas_forbidden_tool_enabled,
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
            witness.next_cursor == AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_NEXT_CURSOR,
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
            "agent_route_policy_issue_count",
            witness.card.issue_count,
            21,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_agent_route_policy_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            5,
            "commands",
        ),
        (
            "route_invariant_count",
            witness.metrics.invariant_count as u64,
            required_agent_route_policy_invariants().len() as u64,
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
        "agent_route_policy_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "agent_route_policy_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "agent_route_policy_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "agent_route_policy_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "agent_route_policy_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("agent_route_policy_card".to_string(), true);

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
            value: serde_json::json!(
                AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_NEXT_CURSOR,
    );

    for axis in AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_AXES {
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
        notes: "metadata-only F-AgentRoutePolicy-LargeModelNoHiddenAuthority: consumes the model-vault blocker and release-audit family source card, binds agent_route_policy issue count 21 to exact route-policy source refs, focused tests, MAS/Pro invariants, rollback, RunEventLog, AnswerPacket, and rejects hidden route/tool/cloud authority, model-vault-as-route-authority, large-model auto-route, PatternBoost/Eidos/lattice live authority, MAS forbidden tools, runtime byte loads, L2/L3/product green, and live dense-70B claims.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:agent-route-policy-large-model-no-hidden-authority:upstream-parser
// Plane: Verification.
// Residency: metadata-only; reads artifact JSON only.
#[derive(Debug)]
struct UpstreamModelVaultCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamModelVaultCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamModelVaultCard {
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

// UAS: uas:agent-route-policy-large-model-no-hidden-authority:family-parser
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
    let route_policy = cards
        .iter()
        .find(|card| {
            card.get("family_id").and_then(serde_json::Value::as_str) == Some("agent_route_policy")
        })
        .ok_or("missing agent_route_policy family")?;
    Ok(FamilySourceCard {
        family_id: route_policy
            .get("family_id")
            .and_then(serde_json::Value::as_str)
            .unwrap_or_default()
            .to_string(),
        issue_count: route_policy
            .get("issue_count")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0),
    })
}

fn red_fixture_results(
    witness: &AgentRoutePolicyLargeModelNoHiddenAuthorityWitness,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "agent_route_policy_large_model_no_hidden_authority",
            "agent_route_policy",
            21,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "model_vault_catalog_release_blocker_card",
            "agent_route_policy",
            21,
        ),
        (
            "wrong_family_rejected",
            true,
            "agent_route_policy_large_model_no_hidden_authority",
            "model_vault_catalog",
            9,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "agent_route_policy_large_model_no_hidden_authority",
            "agent_route_policy",
            0,
        ),
    ] {
        let rejected = AgentRoutePolicyLargeModelNoHiddenAuthorityWitness::new(
            AGENT_ROUTE_POLICY_UPSTREAM_REF,
            AGENT_ROUTE_POLICY_FAMILY_SOURCE_REF,
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
         mutate: fn(&mut agent_core::uas::AgentRoutePolicyLargeModelNoHiddenAuthorityCard),
         results: &mut Vec<(String, bool)>| {
            let mut card = witness.card.clone();
            mutate(&mut card);
            results.push((id.to_string(), card.validate().is_err()));
        };
    add_card(
        "missing_runtime_router_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/LocalAgent/RuntimeRouter.swift")
        },
        &mut results,
    );
    add_card(
        "missing_mas_forbidden_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "mas_forbidden_tools_remain_denied")
        },
        &mut results,
    );
    add_card(
        "hidden_route_authority_rejected",
        |card| card.hidden_route_authority = true,
        &mut results,
    );
    add_card(
        "hidden_tool_authority_rejected",
        |card| card.hidden_tool_authority = true,
        &mut results,
    );
    add_card(
        "hidden_cloud_fallback_rejected",
        |card| card.hidden_cloud_fallback = true,
        &mut results,
    );
    add_card(
        "model_vault_route_authority_rejected",
        |card| card.model_vault_row_as_route_authority = true,
        &mut results,
    );
    add_card(
        "large_model_auto_route_rejected",
        |card| card.large_model_candidate_auto_route = true,
        &mut results,
    );
    add_card(
        "patternboost_eidos_lattice_live_authority_rejected",
        |card| {
            card.patternboost_live_authority = true;
            card.eidos_live_router = true;
            card.lattice_live_router = true;
        },
        &mut results,
    );
    add_card(
        "mas_forbidden_tool_enabled_rejected",
        |card| card.mas_forbidden_tool_enabled = true,
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
