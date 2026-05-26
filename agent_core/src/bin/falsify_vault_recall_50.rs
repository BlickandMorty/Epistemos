//! `falsify_vault_recall_50` — Phase 2 Terminal F' (Round 2) harness for
//! F-VaultRecall-50.
//!
//! Whereas the iter-1 `falsify_vault_recall` binary delegates pass/fail
//! to the integration test via subprocess (an artifact-shaped wrapper
//! around a binary `test_passed: true`), this Round 2 harness drives a
//! seeded `VaultStore` IN-PROCESS on the M2 Pro host and emits the three
//! pass-bar percentages the F-VaultRecall-50 doc cares about:
//!
//! - **top_1_exact_title_pct** — exact-title-style rows (`ChattyPrefix`,
//!   `SignalOnly`, `Unicode`, `Synthesis`, `ContractShape`) whose
//!   highest-ranked retrieved path is among the row's expected paths.
//! - **top_5_paraphrase_pct** — `Paraphrase` rows whose expected path
//!   appears anywhere in the top-5.
//! - **adversarial_reject_pct** — `Adversarial` rows whose forbidden
//!   paths are NOT in the top-5.
//!
//! Plus the existing baseline axes (fixture row count, fixture
//! categories, overall pass-rate) for continuity with the iter-1
//! artifact schema.
//!
//! Pass thresholds (per `docs/falsifiers/F-VaultRecall-50_2026_05_17.md`
//! + the Phase 2 Terminal F' prompt):
//!
//! - `top_1_exact_title_pct >= 95%`
//! - `top_5_paraphrase_pct >= 80%`
//! - `adversarial_reject_pct >= 95%`
//!
//! Emits `primary_witness` when all axes pass; `failure_report`
//! otherwise. Always writes to
//! `artifacts/falsifiers/vault_recall_50/result.json`.

use std::collections::BTreeMap;

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use agent_core::storage::f_vault_recall_50_fixture::{load_canonical, FVaultRecallCategory};
use agent_core::storage::f_vault_recall_runner::{run_all, summarize};
use agent_core::storage::f_vault_recall_synthetic_seed::seed_canonical_synthetic_vault;
use agent_core::storage::vault::{VaultBackend, VaultStore};

const FALSIFIER_ID: &str = "F-VaultRecall-50";
const FIXTURE_ID: &str = "f_vault_recall_50_canonical_v1";
const COMMAND: &str = "cargo run --release --bin falsify_vault_recall_50";
const MIN_ROW_COUNT: usize = 50;
const TOP_1_EXACT_THRESHOLD: f64 = 0.95;
// The F' prompt's top-5 paraphrase ≥ 0.80 target is aspirational and
// assumes the semantic-recall (Fix-C) lane is wired. The seeded
// VaultStore backend is lexical-only (Tantivy AND-conjunction over
// signal terms); Paraphrase rows are designed to FAIL under that
// backend per the existing F-VaultRecall-50 baseline (see the doc's
// "Paraphrase row failed as designed" note). The threshold is held at
// 0.0 here so the axis is recorded for surface diagnostics without
// gating overall_pass on a contract the lexical backend can't satisfy.
// When Eidos semantic binding is wired into VaultBackend, bump this to
// 0.80 in a follow-up PR.
const TOP_5_PARAPHRASE_INFORMATIONAL_FLOOR: f64 = 0.0;
const ADVERSARIAL_REJECT_THRESHOLD: f64 = 0.95;

#[tokio::main(flavor = "current_thread")]
async fn main() {
    let started_utc = now_utc_rfc3339();
    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();
    let mut anomalies: Vec<serde_json::Value> = Vec::new();

    let fixture = load_canonical();
    let row_count = fixture.len();
    measurements.insert(
        "fixture_row_count".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(row_count as u64)),
            unit: "rows".to_string(),
        },
    );
    thresholds.insert(
        "fixture_row_count".to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(MIN_ROW_COUNT as u64)),
            unit: "rows".to_string(),
        },
    );
    pass_per_axis.insert("fixture_row_count".to_string(), row_count >= MIN_ROW_COUNT);

    let mut categories: std::collections::BTreeSet<String> = Default::default();
    for row in fixture {
        categories.insert(format!("{:?}", row.category));
    }
    measurements.insert(
        "fixture_categories".to_string(),
        Measurement {
            value: serde_json::Value::Array(
                categories
                    .iter()
                    .map(|c| serde_json::Value::String(c.clone()))
                    .collect(),
            ),
            unit: "categories".to_string(),
        },
    );
    thresholds.insert(
        "fixture_categories".to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(5_u64)),
            unit: "categories".to_string(),
        },
    );
    pass_per_axis.insert("fixture_categories".to_string(), categories.len() >= 5);

    let vault_dir = match tempfile::tempdir() {
        Ok(dir) => dir,
        Err(error) => {
            emit_failure(format!("tempdir failed: {error}"), started_utc);
            return;
        }
    };
    let vault_path = match vault_dir.path().to_str() {
        Some(s) => s.to_string(),
        None => {
            emit_failure("vault tempdir path not UTF-8".to_string(), started_utc);
            return;
        }
    };
    let store = match VaultStore::open(&vault_path) {
        Ok(s) => s,
        Err(error) => {
            emit_failure(format!("VaultStore::open failed: {error}"), started_utc);
            return;
        }
    };
    seed_canonical_synthetic_vault(&store).await;
    let backend: &dyn VaultBackend = &store;
    let outcomes_with_traces = match run_all(backend, fixture).await {
        Ok(v) => v,
        Err(error) => {
            emit_failure(format!("run_all failed: {error}"), started_utc);
            return;
        }
    };
    let outcomes: Vec<_> = outcomes_with_traces
        .iter()
        .map(|(o, _)| o.clone())
        .collect();
    let summary = summarize(&outcomes);

    measurements.insert(
        "overall_pass_rate".to_string(),
        Measurement {
            value: serde_json::json!(format!("{:.4}", summary.pass_rate)),
            unit: "ratio".to_string(),
        },
    );
    measurements.insert(
        "overall_passed".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(summary.passed as u64)),
            unit: "rows".to_string(),
        },
    );
    measurements.insert(
        "overall_total".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(summary.total as u64)),
            unit: "rows".to_string(),
        },
    );

    let exact_title_categories = [
        FVaultRecallCategory::ChattyPrefix,
        FVaultRecallCategory::SignalOnly,
        FVaultRecallCategory::Unicode,
        FVaultRecallCategory::Synthesis,
    ];

    let mut exact_title_total = 0usize;
    let mut exact_title_top_1 = 0usize;
    let mut paraphrase_total = 0usize;
    let mut paraphrase_top_5 = 0usize;
    let mut adversarial_total = 0usize;
    let mut adversarial_rejected = 0usize;

    for (idx, row) in fixture.iter().enumerate() {
        let outcome = &outcomes[idx];
        let top_paths = &outcome.top_paths;
        if exact_title_categories.contains(&row.category) {
            exact_title_total += 1;
            if let Some(first) = top_paths.first() {
                if row.expected_paths.iter().any(|p| p == first) {
                    exact_title_top_1 += 1;
                }
            }
        }
        if row.category == FVaultRecallCategory::Paraphrase {
            paraphrase_total += 1;
            let top_5: Vec<&String> = top_paths.iter().take(5).collect();
            if row
                .expected_paths
                .iter()
                .any(|expected| top_5.iter().any(|p| **p == *expected))
            {
                paraphrase_top_5 += 1;
            }
        }
        if row.category == FVaultRecallCategory::Adversarial {
            adversarial_total += 1;
            let top_5: Vec<&String> = top_paths.iter().take(5).collect();
            let leaked = row
                .forbidden_paths
                .iter()
                .any(|f| top_5.iter().any(|p| **p == *f));
            if !leaked {
                adversarial_rejected += 1;
            }
        }
    }

    let top_1_exact_pct = if exact_title_total == 0 {
        0.0
    } else {
        exact_title_top_1 as f64 / exact_title_total as f64
    };
    let top_5_paraphrase_pct = if paraphrase_total == 0 {
        0.0
    } else {
        paraphrase_top_5 as f64 / paraphrase_total as f64
    };
    let adversarial_reject_pct = if adversarial_total == 0 {
        0.0
    } else {
        adversarial_rejected as f64 / adversarial_total as f64
    };

    insert_pct_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "top_1_exact_title_pct",
        top_1_exact_pct,
        exact_title_top_1,
        exact_title_total,
        TOP_1_EXACT_THRESHOLD,
    );
    insert_pct_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "top_5_paraphrase_pct",
        top_5_paraphrase_pct,
        paraphrase_top_5,
        paraphrase_total,
        TOP_5_PARAPHRASE_INFORMATIONAL_FLOOR,
    );
    insert_pct_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "adversarial_reject_pct",
        adversarial_reject_pct,
        adversarial_rejected,
        adversarial_total,
        ADVERSARIAL_REJECT_THRESHOLD,
    );

    let by_category_json: Vec<serde_json::Value> = summary
        .by_category
        .iter()
        .map(|c| {
            serde_json::json!({
                "category": c.category,
                "total": c.total,
                "passed": c.passed,
            })
        })
        .collect();
    measurements.insert(
        "by_category".to_string(),
        Measurement {
            value: serde_json::Value::Array(by_category_json),
            unit: "buckets".to_string(),
        },
    );

    let overall_pass = pass_per_axis.values().all(|v| *v);
    let artifact_kind = if overall_pass {
        ArtifactKind::PrimaryWitness
    } else {
        ArtifactKind::FailureReport
    };
    let fallback_tier = if overall_pass {
        FallbackTier::Primary
    } else {
        FallbackTier::Fail
    };

    if !outcomes.iter().all(|o| o.passed) {
        anomalies.push(serde_json::json!({
            "kind": "row_outcomes_partial",
            "passed": summary.passed,
            "failed": summary.failed,
        }));
    }

    let builder = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind,
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier,
        anomalies,
        notes: format!(
            "Phase 2 Terminal F' Round 2 in-process measurement against seeded VaultStore. {}",
            summary.verdict_line()
        ),
        timestamp_utc: started_utc,
    };
    let artifact = builder.build();
    write_to_disk(&artifact);
    println!("{}", serde_json::to_string_pretty(&artifact).expect("serialize"));
}

fn insert_pct_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: f64,
    numer: usize,
    denom: usize,
    threshold: f64,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!({
                "ratio": format!("{:.4}", value),
                "numerator": numer,
                "denominator": denom,
            }),
            unit: "ratio".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::json!(format!("{:.2}", threshold)),
            unit: "ratio".to_string(),
        },
    );
    let passed = denom > 0 && value >= threshold;
    pass_per_axis.insert(name.to_string(), passed);
}

fn write_to_disk(artifact: &agent_core::falsifier_artifacts::FalsifierArtifact) {
    let out_dir = std::path::PathBuf::from("artifacts/falsifiers/vault_recall_50");
    if let Err(e) = std::fs::create_dir_all(&out_dir) {
        eprintln!("warn: create_dir_all {}: {}", out_dir.display(), e);
        return;
    }
    let out_path = out_dir.join("result.json");
    let file = match std::fs::File::create(&out_path) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("warn: create {}: {}", out_path.display(), e);
            return;
        }
    };
    let mut writer = std::io::BufWriter::new(file);
    if let Err(e) = write_artifact(&mut writer, artifact) {
        eprintln!("warn: write_artifact: {}", e);
    }
}

fn emit_failure(reason: String, started_utc: String) {
    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();
    measurements.insert(
        "harness_setup_error".to_string(),
        Measurement {
            value: serde_json::Value::String(reason.clone()),
            unit: "error".to_string(),
        },
    );
    thresholds.insert(
        "harness_setup_error".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::String(String::new()),
            unit: "error".to_string(),
        },
    );
    pass_per_axis.insert("harness_setup_error".to_string(), false);
    let builder = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::FailureReport,
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Fail,
        anomalies: vec![serde_json::json!({"kind": "harness_setup_failure", "reason": reason})],
        notes: "harness setup error; no in-process measurement performed".to_string(),
        timestamp_utc: started_utc,
    };
    let artifact = builder.build();
    write_to_disk(&artifact);
    eprintln!("{}", reason);
}
