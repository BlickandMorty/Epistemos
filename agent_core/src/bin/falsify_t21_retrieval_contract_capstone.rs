//! `falsify_t21_retrieval_contract_capstone`.
//!
//! T21's missing proof is no longer VaultRecall semantic recall by itself; that
//! floor is now green. This capstone verifies the three retrieval-contract
//! witnesses together:
//!
//! - VaultRecall exact/title, semantic/paraphrase, and adversarial floors.
//! - Eidos bridge closed-citation round trip.
//! - PageGather packetized caller + policy acceptance without promoting dense
//!   PageGather.
//!
//! Emits to `artifacts/falsifiers/t21_retrieval_contract_capstone/result.json`.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-T21-RetrievalContract-Capstone";
const FIXTURE_ID: &str = "t21_retrieval_contract_capstone_v1";
const COMMAND: &str = "Tools/falsifiers/f_t21_retrieval_contract_capstone.sh";
const OUTPUT_PATH: &str = "artifacts/falsifiers/t21_retrieval_contract_capstone/result.json";

const VAULT_RECALL_PATH: &str = "artifacts/falsifiers/vault_recall_50/result.json";
const EIDOS_BRIDGE_PATH: &str = "artifacts/falsifiers/eidos_bridge_round_trip/result.json";
const PAGE_GATHER_CALLER_PATH: &str =
    "artifacts/falsifiers/page_gather_packetized_caller/result.json";
const PAGE_GATHER_POLICY_PATH: &str =
    "artifacts/falsifiers/page_gather_packetized_policy_acceptance/result.json";

fn main() -> std::process::ExitCode {
    let artifact = build_artifact();
    let pass = artifact.overall_pass;
    let path = PathBuf::from(OUTPUT_PATH);
    if let Some(parent) = path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create artifact directory: {error}");
            return std::process::ExitCode::from(2);
        }
    }

    match std::fs::File::create(&path).and_then(|mut file| write_artifact(&mut file, &artifact)) {
        Ok(()) if pass => std::process::ExitCode::SUCCESS,
        Ok(()) => std::process::ExitCode::from(1),
        Err(error) => {
            eprintln!("failed to write artifact: {error}");
            std::process::ExitCode::from(2)
        }
    }
}

fn build_artifact() -> agent_core::falsifier_artifacts::FalsifierArtifact {
    let vault = read_json(VAULT_RECALL_PATH);
    let eidos = read_json(EIDOS_BRIDGE_PATH);
    let page_gather_caller = read_json(PAGE_GATHER_CALLER_PATH);
    let page_gather_policy = read_json(PAGE_GATHER_POLICY_PATH);

    let vault_primary = primary_pass(vault.as_ref(), "F-VaultRecall-50");
    let vault_exact_floor = axis_true(vault.as_ref(), "top_1_exact_title_pct");
    let vault_semantic_floor = axis_true(vault.as_ref(), "top_5_paraphrase_pct")
        && measurement_ratio(vault.as_ref(), "top_5_paraphrase_pct").unwrap_or_default() >= 0.80
        && threshold_ratio(vault.as_ref(), "top_5_paraphrase_pct").unwrap_or_default() >= 0.80;
    let vault_adversarial_floor = axis_true(vault.as_ref(), "adversarial_reject_pct");

    let eidos_primary = primary_pass(eidos.as_ref(), "F-Eidos-Bridge-RoundTrip");
    let eidos_closed_citations = axis_true(eidos.as_ref(), "closed_citation_membership")
        && axis_true(eidos.as_ref(), "forged_citation_rejection")
        && axis_true(eidos.as_ref(), "manifest_mismatch_rejection")
        && axis_true(eidos.as_ref(), "retrieve_hits_present")
        && axis_true(eidos.as_ref(), "vault_manifest_prefix");

    let page_gather_caller_pass = artifact_id(
        page_gather_caller.as_ref(),
        "F-PageGather-Packetized-Caller",
    ) && overall_pass(page_gather_caller.as_ref())
        && axis_true(page_gather_caller.as_ref(), "packetized_caller_consumed")
        && axis_true(page_gather_caller.as_ref(), "candidate_pool_broad")
        && axis_true(page_gather_caller.as_ref(), "dense_restore_deferred")
        && axis_true(page_gather_caller.as_ref(), "retained_limit_honored");

    let page_gather_policy_pass = overall_pass(page_gather_policy.as_ref())
        && artifact_id(
            page_gather_policy.as_ref(),
            "F-PageGather-Packetized-Policy-Acceptance",
        )
        && axis_true(page_gather_policy.as_ref(), "packetized_caller_available")
        && axis_true(page_gather_policy.as_ref(), "packetized_caller_consumed")
        && axis_true(
            page_gather_policy.as_ref(),
            "policy_scope_retrieval_and_witness_only",
        )
        && axis_true(page_gather_policy.as_ref(), "dense_primary_not_promoted")
        && axis_true(page_gather_policy.as_ref(), "rollback_keeps_dense_gate_red");

    let dense_page_gather_not_promoted =
        axis_true(page_gather_policy.as_ref(), "dense_primary_not_promoted")
            && axis_true(page_gather_policy.as_ref(), "rollback_keeps_dense_gate_red");

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "vault_recall_primary_witness",
        vault_primary,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "vault_recall_exact_floor",
        vault_exact_floor,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "vault_recall_semantic_floor",
        vault_semantic_floor,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "vault_recall_adversarial_floor",
        vault_adversarial_floor,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "eidos_bridge_primary_witness",
        eidos_primary,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "eidos_closed_citation_round_trip",
        eidos_closed_citations,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_gather_packetized_caller_witness",
        page_gather_caller_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_gather_packetized_policy_witness",
        page_gather_policy_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "dense_page_gather_not_promoted",
        dense_page_gather_not_promoted,
    );

    add_ratio_measurement(
        &mut measurements,
        "vault_top_5_paraphrase_pct",
        measurement_ratio(vault.as_ref(), "top_5_paraphrase_pct").unwrap_or_default(),
    );
    add_ratio_measurement(
        &mut measurements,
        "vault_top_1_exact_title_pct",
        measurement_ratio(vault.as_ref(), "top_1_exact_title_pct").unwrap_or_default(),
    );
    add_dependency_summary(
        &mut measurements,
        &[
            ("vault_recall_50", VAULT_RECALL_PATH, vault.as_ref()),
            ("eidos_bridge_round_trip", EIDOS_BRIDGE_PATH, eidos.as_ref()),
            (
                "page_gather_packetized_caller",
                PAGE_GATHER_CALLER_PATH,
                page_gather_caller.as_ref(),
            ),
            (
                "page_gather_packetized_policy_acceptance",
                PAGE_GATHER_POLICY_PATH,
                page_gather_policy.as_ref(),
            ),
        ],
    );

    let overall = pass_per_axis.values().copied().all(|passed| passed);
    let artifact_kind = if overall {
        ArtifactKind::PrimaryWitness
    } else {
        ArtifactKind::FailureReport
    };
    let fallback_tier = if overall {
        FallbackTier::Primary
    } else {
        FallbackTier::Fail
    };
    let anomalies = dependency_anomalies(&[
        ("vault_recall_50", VAULT_RECALL_PATH, vault.as_ref()),
        ("eidos_bridge_round_trip", EIDOS_BRIDGE_PATH, eidos.as_ref()),
        (
            "page_gather_packetized_caller",
            PAGE_GATHER_CALLER_PATH,
            page_gather_caller.as_ref(),
        ),
        (
            "page_gather_packetized_policy_acceptance",
            PAGE_GATHER_POLICY_PATH,
            page_gather_policy.as_ref(),
        ),
    ]);

    ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier,
        anomalies,
        notes: "T21 capstone witness over VaultRecall semantic/exact/adversarial floors, Eidos closed citations, and PageGather packetized retrieval policy; dense PageGather remains unpromoted.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build()
}

fn read_json(path: &str) -> Option<serde_json::Value> {
    std::fs::read_to_string(path)
        .ok()
        .and_then(|text| serde_json::from_str(&text).ok())
}

fn artifact_id(value: Option<&serde_json::Value>, expected: &str) -> bool {
    value
        .and_then(|artifact| artifact.get("falsifier_id"))
        .and_then(|value| value.as_str())
        .is_some_and(|id| id == expected)
}

fn overall_pass(value: Option<&serde_json::Value>) -> bool {
    value
        .and_then(|artifact| artifact.get("overall_pass"))
        .and_then(|value| value.as_bool())
        .unwrap_or(false)
}

fn primary_pass(value: Option<&serde_json::Value>, expected_id: &str) -> bool {
    artifact_id(value, expected_id)
        && overall_pass(value)
        && value
            .and_then(|artifact| artifact.get("artifact_kind"))
            .and_then(|value| value.as_str())
            .is_some_and(|kind| kind == "primary_witness")
}

fn axis_true(value: Option<&serde_json::Value>, axis: &str) -> bool {
    value
        .and_then(|artifact| artifact.get("pass_per_axis"))
        .and_then(|axes| axes.get(axis))
        .and_then(|value| value.as_bool())
        .unwrap_or(false)
}

fn measurement_ratio(value: Option<&serde_json::Value>, key: &str) -> Option<f64> {
    let ratio = value?
        .get("measurements")?
        .get(key)?
        .get("value")?
        .get("ratio")?;
    ratio
        .as_f64()
        .or_else(|| ratio.as_str().and_then(|text| text.parse::<f64>().ok()))
}

fn threshold_ratio(value: Option<&serde_json::Value>, key: &str) -> Option<f64> {
    let ratio = value?
        .get("acceptance_thresholds")?
        .get(key)?
        .get("value")?;
    ratio
        .as_f64()
        .or_else(|| ratio.as_str().and_then(|text| text.parse::<f64>().ok()))
}

fn add_ratio_measurement(measurements: &mut BTreeMap<String, Measurement>, key: &str, value: f64) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value: serde_json::json!(format!("{value:.4}")),
            unit: "ratio".to_string(),
        },
    );
}

fn add_dependency_summary(
    measurements: &mut BTreeMap<String, Measurement>,
    dependencies: &[(&str, &str, Option<&serde_json::Value>)],
) {
    measurements.insert(
        "dependency_artifacts".to_string(),
        Measurement {
            value: serde_json::Value::Array(
                dependencies
                    .iter()
                    .map(|(name, path, artifact)| {
                        serde_json::json!({
                            "name": name,
                            "path": path,
                            "falsifier_id": artifact
                                .and_then(|value| value.get("falsifier_id"))
                                .and_then(|value| value.as_str())
                                .unwrap_or("missing"),
                            "overall_pass": overall_pass(*artifact),
                            "artifact_kind": artifact
                                .and_then(|value| value.get("artifact_kind"))
                                .and_then(|value| value.as_str())
                                .unwrap_or("missing"),
                        })
                    })
                    .collect(),
            ),
            unit: "artifacts".to_string(),
        },
    );
}

fn dependency_anomalies(
    dependencies: &[(&str, &str, Option<&serde_json::Value>)],
) -> Vec<serde_json::Value> {
    dependencies
        .iter()
        .filter_map(|(name, path, artifact)| {
            if artifact.is_none() {
                Some(serde_json::json!({
                    "kind": "missing_dependency_artifact",
                    "name": name,
                    "path": path,
                }))
            } else if !overall_pass(*artifact) {
                Some(serde_json::json!({
                    "kind": "dependency_artifact_not_green",
                    "name": name,
                    "path": path,
                }))
            } else {
                None
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn measurement_ratio_parses_string_ratio() {
        let artifact = serde_json::json!({
            "measurements": {
                "top_5": {
                    "value": {"ratio": "0.9800"},
                    "unit": "ratio"
                }
            }
        });
        assert_eq!(measurement_ratio(Some(&artifact), "top_5"), Some(0.98));
    }

    #[test]
    fn threshold_ratio_parses_string_threshold() {
        let artifact = serde_json::json!({
            "acceptance_thresholds": {
                "top_5": {
                    "operator": ">=",
                    "value": "0.80",
                    "unit": "ratio"
                }
            }
        });
        assert_eq!(threshold_ratio(Some(&artifact), "top_5"), Some(0.80));
    }
}
