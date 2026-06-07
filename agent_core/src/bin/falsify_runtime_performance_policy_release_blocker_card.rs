//! `falsify_runtime_performance_policy_release_blocker_card`.
//!
//! Metadata-only witness that binds retained runtime performance policy blockers to
//! exact backend-runtime, thermal, route-profile, performance-settings, and
//! benchmark-evidence surfaces without granting route, runtime, WRV, MAS, L2,
//! L3, or product proof.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_runtime_performance_policy_invariants,
    required_runtime_performance_policy_source_refs, RuntimePerformancePolicyReleaseBlockerWitness,
    RUNTIME_PERFORMANCE_POLICY_FAMILY_SOURCE_REF,
    RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    RUNTIME_PERFORMANCE_POLICY_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-RuntimePerformancePolicy-ReleaseBlockerCard";
const FIXTURE_ID: &str = "runtime_performance_policy_release_blocker_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_runtime_performance_policy_release_blocker_card.sh";
const RESULT: &str =
    "artifacts/falsifiers/runtime_performance_policy_release_blocker_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/ui_shell_source_guard_release_blocker_card/result.json";
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
        artifact.measurements["runtime_performance_policy_issue_count"].value,
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
    let witness = RuntimePerformancePolicyReleaseBlockerWitness::new(
        RUNTIME_PERFORMANCE_POLICY_UPSTREAM_REF,
        RUNTIME_PERFORMANCE_POLICY_FAMILY_SOURCE_REF,
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
            "upstream_ui_shell_source_guard_card_pass",
            upstream.overall_pass,
        ),
        (
            "upstream_next_cursor_runtime_performance_policy",
            upstream.next_cursor == "runtime_performance_policy_release_blocker_card",
        ),
        (
            "runtime_performance_policy_family_bound",
            witness.card.family_id == "runtime_performance_policy",
        ),
        (
            "runtime_performance_policy_issue_count_retained",
            witness.card.issue_count == family.issue_count && witness.card.issue_count == 3,
        ),
        (
            "source_refs_cover_runtime_performance_policy",
            witness.metrics.source_ref_count
                == required_runtime_performance_policy_source_refs().len(),
        ),
        (
            "focused_commands_cover_runtime_performance_tests",
            witness.metrics.focused_command_count >= 5,
        ),
        (
            "runtime_performance_invariants_bound",
            witness.metrics.invariant_count
                == required_runtime_performance_policy_invariants().len(),
        ),
        (
            "backend_runtime_contract_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Engine/BackendRuntimeContract.swift"),
        ),
        (
            "thermal_guard_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/State/ThermalGuard.swift"),
        ),
        (
            "benchmark_evidence_test_source_bound",
            witness.card.source_refs.iter().any(|value| {
                value == "EpistemosTests/Benchmarks/R15BenchmarkEvidenceLedgerTests.swift"
            }),
        ),
        (
            "no_performance_surface_as_capability_proof",
            !witness.card.performance_surface_as_capability_proof,
        ),
        (
            "benchmark_not_runtime_proof",
            !witness.card.benchmark_as_runtime_proof,
        ),
        (
            "stale_benchmark_baseline_rejected",
            !witness.card.stale_benchmark_baseline_accepted,
        ),
        (
            "thermal_policy_not_bypassed",
            !witness.card.thermal_policy_bypassed,
        ),
        (
            "memory_pressure_not_bypassed",
            !witness.card.memory_pressure_bypassed,
        ),
        (
            "cancellation_timeout_required",
            !witness.card.cancellation_timeout_missing,
        ),
        (
            "runtime_lane_performance_bounded",
            !witness.card.runtime_lane_performance_unbounded,
        ),
        (
            "settings_performance_not_route_unlock",
            !witness.card.settings_performance_unlocks_route,
        ),
        (
            "answer_packet_caveat_visible",
            !witness.card.answer_packet_caveat_hidden,
        ),
        (
            "mas_pro_boundaries_not_collapsed",
            !witness.card.mas_pro_boundary_collapsed,
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
            "no_benchmark_model_bytes_or_provider_calls",
            witness.metrics.benchmark_bytes_loaded == 0
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
            witness.next_cursor == RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
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
            "runtime_performance_policy_issue_count",
            witness.card.issue_count,
            3,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_runtime_performance_policy_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            5,
            "commands",
        ),
        (
            "runtime_performance_invariant_count",
            witness.metrics.invariant_count as u64,
            required_runtime_performance_policy_invariants().len() as u64,
            "invariants",
        ),
        (
            "benchmark_bytes_loaded_total",
            witness.metrics.benchmark_bytes_loaded,
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
        "runtime_performance_policy_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "runtime_performance_policy_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "runtime_performance_policy_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "runtime_performance_policy_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "runtime_performance_policy_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("runtime_performance_policy_card".to_string(), true);

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
            value: serde_json::json!(RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    );

    for axis in RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_AXES {
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
        notes: "metadata-only F-RuntimePerformancePolicy-ReleaseBlockerCard: consumes UI-shell source-guard blocker and release-audit family source card, binds runtime_performance_policy issue count 3 to BackendRuntimeContract, TriageService, AppleIntelligenceService, RuntimeExecutor, MetalRuntimeManager, ThermalGuard, ThermalMonitor, route profiles, RuntimeRouter, performance settings, focused runtime/performance tests, and benchmark evidence tests, and rejects performance surfaces as capability proof, benchmark-as-runtime proof, stale baselines, thermal or memory-pressure bypass, missing cancellation/timeouts, unbounded runtime lanes, settings route unlocks, hidden AnswerPacket caveats, MAS/Pro collapse, L2/L3/product green, provider calls, byte leaks, and live dense-70B claims.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:runtime-performance-policy-release-blocker-card:upstream-parser
// Plane: Verification.
// Residency: metadata-only; reads artifact JSON only.
#[derive(Debug)]
struct UpstreamUiShellSourceGuardCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamUiShellSourceGuardCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamUiShellSourceGuardCard {
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

// UAS: uas:runtime-performance-policy-release-blocker-card:family-parser
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
                == Some("runtime_performance_policy")
        })
        .ok_or("missing runtime_performance_policy family")?;
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

fn red_fixture_results(
    witness: &RuntimePerformancePolicyReleaseBlockerWitness,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "runtime_performance_policy_release_blocker_card",
            "runtime_performance_policy",
            3,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "ui_shell_source_guard_release_blocker_card",
            "runtime_performance_policy",
            3,
        ),
        (
            "wrong_family_rejected",
            true,
            "runtime_performance_policy_release_blocker_card",
            "ui_shell_source_guard",
            3,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "runtime_performance_policy_release_blocker_card",
            "runtime_performance_policy",
            0,
        ),
    ] {
        let rejected = RuntimePerformancePolicyReleaseBlockerWitness::new(
            RUNTIME_PERFORMANCE_POLICY_UPSTREAM_REF,
            RUNTIME_PERFORMANCE_POLICY_FAMILY_SOURCE_REF,
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
         mutate: fn(&mut agent_core::uas::RuntimePerformancePolicyReleaseBlockerCard),
         results: &mut Vec<(String, bool)>| {
            let mut card = witness.card.clone();
            mutate(&mut card);
            results.push((id.to_string(), card.validate().is_err()));
        };
    add_card(
        "missing_backend_runtime_contract_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Engine/BackendRuntimeContract.swift")
        },
        &mut results,
    );
    add_card(
        "missing_thermal_guard_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/State/ThermalGuard.swift")
        },
        &mut results,
    );
    add_card(
        "missing_benchmark_evidence_source_rejected",
        |card| {
            card.source_refs.retain(|value| {
                value != "EpistemosTests/Benchmarks/R15BenchmarkEvidenceLedgerTests.swift"
            })
        },
        &mut results,
    );
    add_card(
        "missing_latency_budget_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "p95_p99_latency_budgets_must_be_visible")
        },
        &mut results,
    );
    add_card(
        "missing_thermal_policy_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "thermal_pressure_defers_or_abstains_before_runtime_claim")
        },
        &mut results,
    );
    add_card(
        "performance_surface_capability_proof_rejected",
        |card| card.performance_surface_as_capability_proof = true,
        &mut results,
    );
    add_card(
        "benchmark_runtime_proof_rejected",
        |card| card.benchmark_as_runtime_proof = true,
        &mut results,
    );
    add_card(
        "stale_benchmark_baseline_rejected_fixture",
        |card| card.stale_benchmark_baseline_accepted = true,
        &mut results,
    );
    add_card(
        "thermal_policy_bypass_rejected",
        |card| card.thermal_policy_bypassed = true,
        &mut results,
    );
    add_card(
        "memory_pressure_bypass_rejected",
        |card| card.memory_pressure_bypassed = true,
        &mut results,
    );
    add_card(
        "missing_cancellation_timeout_rejected",
        |card| card.cancellation_timeout_missing = true,
        &mut results,
    );
    add_card(
        "runtime_lane_unbounded_rejected",
        |card| card.runtime_lane_performance_unbounded = true,
        &mut results,
    );
    add_card(
        "settings_performance_unlock_route_rejected",
        |card| card.settings_performance_unlocks_route = true,
        &mut results,
    );
    add_card(
        "answer_packet_caveat_hidden_rejected",
        |card| card.answer_packet_caveat_hidden = true,
        &mut results,
    );
    add_card(
        "mas_pro_boundary_collapse_rejected",
        |card| card.mas_pro_boundary_collapsed = true,
        &mut results,
    );
    add_card(
        "combined_performance_authority_rejected",
        |card| {
            card.performance_surface_as_capability_proof = true;
            card.benchmark_as_runtime_proof = true;
            card.runtime_lane_performance_unbounded = true;
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
        "benchmark_byte_leak_rejected",
        |card| card.benchmark_bytes_loaded = 1,
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
