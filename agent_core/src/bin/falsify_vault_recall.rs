//! `falsify_vault_recall` — T23B Phase 2 Terminal F harness binary for
//! F-VaultRecall-50.
//!
//! The F-VaultRecall-50 gate already has a runtime witness on this
//! repo: the integration test
//! `agent_core/tests/f_vault_recall_50.rs::f_vault_recall_50_canonical_rows_against_seeded_vault`
//! exercises the canonical 50-row fixture against a Tantivy-backed
//! seeded `VaultStore` and asserts the documented pass profile
//! (4 categories pass; Paraphrase pinned to V1.x Fix-C deferred).
//!
//! This binary:
//! 1. Loads the canonical fixture via `load_canonical()` — proves the
//!    fixture is present + has the expected row + category counts (50
//!    rows; 5 categories — pinned per
//!    `docs/falsifiers/F_VAULT_RECALL_50_2026_05_18.md`).
//! 2. Invokes `cargo test --test f_vault_recall_50` as a subprocess to
//!    drive the existing seeded-vault integration test; captures
//!    pass/fail.
//! 3. Records both the fixture metadata + the test outcome in a
//!    schema-conformant artifact.
//!
//! Emits a **primary_witness** when the integration test passes and the
//! fixture metadata matches the canonical counts; **failure_report**
//! otherwise. The artifact is the witness; the test is the gate.
//!
//! Source:
//! - `docs/falsifiers/F-VaultRecall-50_2026_05_17.md`
//! - `docs/falsifiers/F-VaultRecall-50_baseline_2026_05_17.md`
//! - `docs/falsifiers/F_VAULT_RECALL_50_2026_05_18.md`
//! - `agent_core/src/storage/f_vault_recall_50_fixture.rs`
//! - `agent_core/tests/f_vault_recall_50.rs`

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::time::Instant;

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use agent_core::storage::f_vault_recall_50_fixture::load_canonical;

const FALSIFIER_ID: &str = "F-VaultRecall-50";
const FIXTURE_ID: &str = "f_vault_recall_50_canonical_v1";
const COMMAND: &str = "cargo run --release --bin falsify_vault_recall";
const TEST_NAME: &str = "f_vault_recall_50_canonical_rows_against_seeded_vault";

/// Minimum row count per
/// `docs/falsifiers/F_VAULT_RECALL_50_2026_05_18.md` ("50-200 candidates"
/// floor). The canonical fixture has grown well past the historical 50
/// baseline — the gate is `>= 50` so adding fixture rows never
/// regresses the artifact.
const MIN_ROW_COUNT: usize = 50;

fn main() {
    let started_utc = now_utc_rfc3339();
    let start = Instant::now();
    let skip_integration = std::env::args().any(|a| a == "--skip-integration-test");

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();
    let mut anomalies: Vec<serde_json::Value> = Vec::new();

    // -- Axis 1: fixture row count ---------------------------------
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
    pass_per_axis.insert(
        "fixture_row_count".to_string(),
        row_count >= MIN_ROW_COUNT,
    );

    // -- Axis 2: category coverage ---------------------------------
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
            unit: "category_names".to_string(),
        },
    );
    thresholds.insert(
        "fixture_categories".to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(5)),
            unit: "distinct".to_string(),
        },
    );
    pass_per_axis.insert("fixture_categories".to_string(), categories.len() >= 5);

    // -- Axis 3: integration test pass ------------------------------
    let test_outcome = if skip_integration {
        TestOutcome::Unavailable {
            detail: "--skip-integration-test flag set; pass evidence \
                     deferred to the existing cargo test invocation"
                .to_string(),
        }
    } else {
        run_baseline_integration_test()
    };
    let test_passed = matches!(test_outcome, TestOutcome::Passed { .. });
    let test_unavailable = matches!(test_outcome, TestOutcome::Unavailable { .. });
    measurements.insert(
        "integration_test_passed".to_string(),
        Measurement {
            value: serde_json::Value::Bool(test_passed),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        "integration_test_passed".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert("integration_test_passed".to_string(), test_passed);

    let elapsed_seconds = start.elapsed().as_secs_f64();
    measurements.insert(
        "harness_wall_clock_seconds".to_string(),
        Measurement {
            value: serde_json::Value::Number(
                serde_json::Number::from_f64(elapsed_seconds)
                    .unwrap_or_else(|| serde_json::Number::from(0)),
            ),
            unit: "seconds".to_string(),
        },
    );

    let (kind, tier, notes) = match &test_outcome {
        TestOutcome::Passed { stdout_tail } => (
            ArtifactKind::PrimaryWitness,
            FallbackTier::Primary,
            format!(
                "F-VaultRecall-50 integration test {TEST_NAME} PASSED (tokio + seeded VaultStore + Tantivy). \
                 stdout_tail={stdout_tail}"
            ),
        ),
        TestOutcome::Failed { detail } => {
            anomalies.push(serde_json::json!({
                "kind": "test_failure",
                "detail": detail,
            }));
            (
                ArtifactKind::FailureReport,
                FallbackTier::Fail,
                format!("F-VaultRecall-50 integration test {TEST_NAME} FAILED: {detail}"),
            )
        }
        TestOutcome::Unavailable { detail } => {
            anomalies.push(serde_json::json!({
                "kind": "cargo_unavailable",
                "detail": detail,
            }));
            (
                ArtifactKind::FallbackWitness,
                FallbackTier::Fallback,
                format!(
                    "F-VaultRecall-50 fixture metadata verified; integration test \
                     could not be invoked from this harness (cargo unavailable in PATH). \
                     Reproduce via: cargo test --manifest-path agent_core/Cargo.toml \
                     --test f_vault_recall_50 -- --nocapture. Detail: {detail}"
                ),
            )
        }
    };

    if test_unavailable {
        // When cargo is unavailable we cannot honestly claim a pass on
        // the integration test axis — flip it to false but keep the
        // fixture-metadata axes honest.
        pass_per_axis.insert("integration_test_passed".to_string(), false);
    }

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: kind,
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: tier,
        anomalies,
        notes,
        timestamp_utc: started_utc,
    }
    .build();

    let path = PathBuf::from("artifacts/falsifiers/vault_recall_50/result.json");
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("create artifacts directory");
    }
    let mut file = std::fs::File::create(&path).expect("open artifact for write");
    write_artifact(&mut file, &artifact).expect("write artifact");

    println!(
        "F-VaultRecall-50: overall_pass={} fallback_tier={} elapsed_seconds={:.2} artifact={}",
        artifact.overall_pass,
        artifact.fallback_tier,
        elapsed_seconds,
        path.display()
    );

    if !artifact.overall_pass {
        std::process::exit(1);
    }
}

enum TestOutcome {
    Passed { stdout_tail: String },
    Failed { detail: String },
    Unavailable { detail: String },
}

fn run_baseline_integration_test() -> TestOutcome {
    let cargo = match std::env::var_os("CARGO") {
        Some(c) => PathBuf::from(c),
        None => PathBuf::from("cargo"),
    };
    let output = std::process::Command::new(&cargo)
        .args([
            "test",
            "--manifest-path",
            "agent_core/Cargo.toml",
            "--release",
            "--test",
            "f_vault_recall_50",
            "--",
            "--exact",
            TEST_NAME,
        ])
        .output();
    let output = match output {
        Ok(o) => o,
        Err(e) => {
            return TestOutcome::Unavailable {
                detail: format!("failed to spawn cargo: {e}"),
            };
        }
    };
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();
    if output.status.success() {
        let tail: String = stdout
            .lines()
            .filter(|l| l.contains("test result") || l.contains("running"))
            .collect::<Vec<_>>()
            .join(" | ");
        TestOutcome::Passed { stdout_tail: tail }
    } else {
        TestOutcome::Failed {
            detail: format!(
                "exit={:?}; stderr_tail={}",
                output.status.code(),
                stderr.lines().rev().take(5).collect::<Vec<_>>().join(" / ")
            ),
        }
    }
}
