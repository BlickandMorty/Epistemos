//! `falsify_ulp_oracle` — T23B Phase 2 Terminal F harness binary for
//! F-ULP-Oracle.
//!
//! Drives `agent_core::research::fulp_oracle::run_fulp_oracle` against
//! the canonical 414,048-point grid (412k log-sampled + 2,048
//! adversarial) and emits a schema-conformant artifact at
//! `artifacts/falsifiers/ulp_oracle/result.json`.
//!
//! The kernel under test is `ReferenceRoundedKernel` — the CPU reference
//! that the Metal `morph_eval_reduced.metal` kernel must match. Per
//! `docs/falsifiers/F-ULP-Oracle_2026_05_17.md` §3 the reference itself
//! is fp64; comparison rounds to fp16 only at the comparison step. This
//! makes the CPU reference a **primary witness** for the floor: max ULP
//! abs-diff ≤ 2 by construction of the rounded kernel.
//!
//! Source:
//! - `docs/falsifiers/F-ULP-Oracle_2026_05_17.md` §§2-8
//! - `docs/falsifiers/F_ULP_ORACLE_2026_05_18.md` (T23B handbook row)
//! - `docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md`
//! - `docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md` §Terminal F target 4

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::time::Instant;

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use agent_core::research::fulp_oracle::{
    run_fulp_oracle, FulpRunConfig, ReferenceRoundedKernel, ULP_TOLERANCE_FP16,
};

const FALSIFIER_ID: &str = "F-ULP-Oracle";
const FIXTURE_ID: &str = "fulp_acceptance_grid_412k_log_2k_adversarial_v1";
const COMMAND: &str = "cargo run --release --bin falsify_ulp_oracle";
const BUDGET_SECONDS: u64 = 90;

fn main() {
    let started_utc = now_utc_rfc3339();
    let start = Instant::now();

    let result = run_fulp_oracle(FulpRunConfig::ACCEPTANCE, &ReferenceRoundedKernel);

    let elapsed = start.elapsed();
    let elapsed_seconds = elapsed.as_secs_f64();

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();
    let mut anomalies: Vec<serde_json::Value> = Vec::new();
    let kind;
    let tier;
    let notes;
    let commit_sha = agent_core::falsifier_artifacts::current_commit_sha();

    match result {
        Ok(witness) => {
            for stat in &witness.stats {
                let axis = format!("max_ulp_{}", stat.operation.as_str());
                measurements.insert(
                    axis.clone(),
                    Measurement {
                        value: serde_json::Value::Number(serde_json::Number::from(stat.max_ulp)),
                        unit: "ulp_fp16".to_string(),
                    },
                );
                thresholds.insert(
                    axis.clone(),
                    AcceptanceThreshold {
                        operator: "<=".to_string(),
                        value: serde_json::Value::Number(serde_json::Number::from(
                            ULP_TOLERANCE_FP16,
                        )),
                        unit: "ulp_fp16".to_string(),
                    },
                );
                pass_per_axis.insert(axis, stat.max_ulp <= ULP_TOLERANCE_FP16);
            }

            measurements.insert(
                "wall_clock_seconds".to_string(),
                Measurement {
                    value: serde_json::Value::Number(
                        serde_json::Number::from_f64(elapsed_seconds)
                            .unwrap_or_else(|| serde_json::Number::from(0)),
                    ),
                    unit: "seconds".to_string(),
                },
            );
            thresholds.insert(
                "wall_clock_seconds".to_string(),
                AcceptanceThreshold {
                    operator: "<=".to_string(),
                    value: serde_json::Value::Number(serde_json::Number::from(BUDGET_SECONDS)),
                    unit: "seconds".to_string(),
                },
            );
            pass_per_axis.insert(
                "wall_clock_seconds".to_string(),
                elapsed_seconds <= BUDGET_SECONDS as f64,
            );

            measurements.insert(
                "evaluations_total".to_string(),
                Measurement {
                    value: serde_json::Value::Number(serde_json::Number::from(
                        witness.operation_evaluations as u64,
                    )),
                    unit: "count".to_string(),
                },
            );
            thresholds.insert(
                "evaluations_total".to_string(),
                AcceptanceThreshold {
                    operator: ">=".to_string(),
                    value: serde_json::Value::Number(serde_json::Number::from(414_048u64 * 3)),
                    unit: "count".to_string(),
                },
            );
            pass_per_axis.insert(
                "evaluations_total".to_string(),
                witness.operation_evaluations >= 414_048 * 3,
            );

            kind = ArtifactKind::PrimaryWitness;
            tier = FallbackTier::Primary;
            notes = format!(
                "kernel=cpu_reference_rounded_fp16_v1; grid_fingerprint={}; \
                 budget_target_seconds={}; F-ULP-Oracle CPU reference \
                 produces primary witness — Metal morph_eval_reduced.metal \
                 kernel measurement still pending (W-40 / T12)",
                witness.grid_fingerprint, witness.budget_target_seconds
            );
        }
        Err(e) => {
            anomalies.push(serde_json::json!({
                "kind": "oracle_error",
                "detail": format!("{e:?}"),
            }));
            measurements.insert(
                "wall_clock_seconds".to_string(),
                Measurement {
                    value: serde_json::Value::Number(
                        serde_json::Number::from_f64(elapsed_seconds)
                            .unwrap_or_else(|| serde_json::Number::from(0)),
                    ),
                    unit: "seconds".to_string(),
                },
            );
            thresholds.insert(
                "wall_clock_seconds".to_string(),
                AcceptanceThreshold {
                    operator: "<=".to_string(),
                    value: serde_json::Value::Number(serde_json::Number::from(BUDGET_SECONDS)),
                    unit: "seconds".to_string(),
                },
            );
            pass_per_axis.insert("wall_clock_seconds".to_string(), false);
            kind = ArtifactKind::FailureReport;
            tier = FallbackTier::Fail;
            notes = format!("F-ULP-Oracle harness error: {e:?}");
        }
    }

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: kind,
        command: COMMAND.to_string(),
        commit_sha,
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

    let path = artifact_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("create artifacts directory");
    }
    let mut file = std::fs::File::create(&path).expect("open artifact for write");
    write_artifact(&mut file, &artifact).expect("write artifact");

    println!(
        "F-ULP-Oracle: overall_pass={} fallback_tier={} elapsed_seconds={:.2} artifact={}",
        artifact.overall_pass,
        artifact.fallback_tier,
        elapsed_seconds,
        path.display()
    );

    if !artifact.overall_pass {
        std::process::exit(1);
    }
}

fn artifact_path() -> PathBuf {
    PathBuf::from("artifacts/falsifiers/ulp_oracle/result.json")
}
