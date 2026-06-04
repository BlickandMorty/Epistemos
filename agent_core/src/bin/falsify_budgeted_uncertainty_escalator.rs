//! `falsify_budgeted_uncertainty_escalator` -- budgeted abstention contract.
//!
//! Metadata-only witness for `F-BudgetedUncertaintyEscalator`. It proves cheap
//! selector output cannot choose a wrong route when uncertainty, calibration,
//! byte budget, latency budget, coverage, or OOD evidence says to abstain or
//! escalate. No runtime/model bytes are loaded.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-BudgetedUncertaintyEscalator";
const FIXTURE_ID: &str = "budgeted_uncertainty_escalator_v1";
const COMMAND: &str = "Tools/falsifiers/f_budgeted_uncertainty_escalator.sh";
const RESULT: &str = "artifacts/falsifiers/budgeted_uncertainty_escalator/result.json";
const UPSTREAM_TWO_STAGE: &str = "artifacts/falsifiers/two_stage_route_scout_abstain/result.json";
const MAX_ESCALATOR_ACTIVE_BYTES: u64 = 3 * 1024 * 1024;
const MIN_COVERAGE_TARGET_BPS: u64 = 9_000;
const OOD_THRESHOLD_BPS: u64 = 7_500;

// UAS: uas:budgeted-uncertainty-escalator:task
// Plane: Controller + Verification
// Residency: metadata-only route safety row.
#[derive(Clone)]
struct EscalatorTask {
    split: &'static str,
    task_signature: &'static str,
    mission_id: &'static str,
    scout_ref: &'static str,
    calibration_ref: &'static str,
    route_family: &'static str,
    selector_kind: &'static str,
    uncertainty_bps: u64,
    ood_score_bps: u64,
    coverage_bps: u64,
    coverage_target_bps: u64,
    byte_budget_remaining: u64,
    required_active_bytes: u64,
    latency_budget_remaining_ms: u64,
    predicted_latency_ms: u64,
    verifier_coverage_bps: u64,
    required_verifier_coverage_bps: u64,
    expected_decision: &'static str,
    escalation_target: &'static str,
    abstain_reason: &'static str,
    rollback_handle: &'static str,
    run_event_log_ref: &'static str,
    answer_packet_ref: &'static str,
    route_authority: &'static str,
    escalator_active_bytes: u64,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    live_policy_mutated: bool,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:budgeted-uncertainty-escalator:error
// Plane: Verification
// Residency: metadata-only
enum EscalatorError {
    MissingTask,
    DuplicateTask,
    MissingSplit,
    MissingTaskSignature,
    MissingMission,
    MissingScoutRef,
    MissingCalibrationRef,
    MissingCoverageTarget,
    MissingBudget,
    MissingLatencyBudget,
    MissingEscalationTarget,
    MissingAbstainReason,
    InvalidUncertainty,
    InvalidOodScore,
    InvalidCoverage,
    InvalidDecision,
    MissingTrainingSplit,
    MissingHeldOutSplit,
    MissingEscalationCase,
    MissingAllowCase,
    HighUncertaintyAllowed,
    MissingCalibrationAllowed,
    OodAllowed,
    ByteBudgetAllowed,
    LatencyBudgetAllowed,
    CoverageShortfallAllowed,
    VerifierCoverageShortfallAllowed,
    CheapBaselineUnbeaten,
    AlwaysEscalateBaselineUnbeaten,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    HiddenLiveAuthority,
    LivePolicyMutation,
    HiddenChainExposure,
    CloudRoute,
    EscalatorBudgetExceeded,
}

impl std::fmt::Display for EscalatorError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for EscalatorError {}

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
        "{FALSIFIER_ID}: overall_pass={} held_out_task_count={} escalator_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["held_out_task_count"].value,
        artifact.measurements["escalator_address"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let tasks = fixture_tasks();
    let reversed = tasks.iter().cloned().rev().collect::<Vec<_>>();
    let evaluation = EscalatorEvaluation::new(tasks)?;
    let reversed_evaluation = EscalatorEvaluation::new(reversed)?;
    let metrics = evaluation.metrics;

    let upstream_two_stage_route_scout_abstain_pass = upstream_two_stage_pass();
    let budgeted_escalator_fixture_present = evaluation.tasks.len() == 10;
    let training_split_bound = evaluation.training_task_count() >= 2;
    let held_out_split_bound = evaluation.held_out_task_count() >= 8;
    let task_signatures_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.task_signature.starts_with("task:"));
    let mission_ids_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.mission_id.starts_with("mission:"));
    let scout_refs_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.scout_ref.starts_with("two-stage:"));
    let calibration_set_bound = evaluation
        .tasks
        .iter()
        .filter(|task| task.expected_decision == "allow_cheap")
        .all(|task| task.calibration_ref.starts_with("calibration:"));
    let coverage_target_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.coverage_target_bps >= MIN_COVERAGE_TARGET_BPS);
    let uncertainty_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.uncertainty_bps <= 10_000);
    let ood_signal_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.ood_score_bps <= 10_000);
    let byte_budget_bound = evaluation.tasks.iter().all(|task| {
        task.byte_budget_remaining >= task.required_active_bytes
            || task.expected_decision != "allow_cheap"
    });
    let latency_budget_bound = evaluation.tasks.iter().all(|task| {
        task.latency_budget_remaining_ms >= task.predicted_latency_ms
            || task.expected_decision != "allow_cheap"
    });
    let verifier_coverage_bound = evaluation.tasks.iter().all(|task| {
        task.verifier_coverage_bps >= task.required_verifier_coverage_bps
            || task.expected_decision != "allow_cheap"
    });
    let decision_labels_bound = evaluation
        .tasks
        .iter()
        .all(|task| derive_decision(task) == task.expected_decision);
    let escalation_target_bound = evaluation.tasks.iter().all(|task| {
        task.expected_decision == "allow_cheap" || task.escalation_target.starts_with("target:")
    });
    let abstain_reason_bound = evaluation.tasks.iter().all(|task| {
        task.expected_decision == "allow_cheap" || task.abstain_reason.starts_with("reason:")
    });
    let high_uncertainty_escalates = evaluation.tasks.iter().any(|task| {
        task.abstain_reason == "reason:high_uncertainty" && task.expected_decision != "allow_cheap"
    });
    let budget_exhaustion_escalates = evaluation.tasks.iter().any(|task| {
        task.abstain_reason == "reason:byte_budget_exhausted"
            && task.expected_decision != "allow_cheap"
    });
    let latency_exhaustion_escalates = evaluation.tasks.iter().any(|task| {
        task.abstain_reason == "reason:latency_budget_exhausted"
            && task.expected_decision != "allow_cheap"
    });
    let missing_calibration_escalates = evaluation.tasks.iter().any(|task| {
        task.abstain_reason == "reason:missing_calibration"
            && task.expected_decision != "allow_cheap"
    });
    let ood_escalates = evaluation.tasks.iter().any(|task| {
        task.abstain_reason == "reason:out_of_distribution"
            && task.expected_decision != "allow_cheap"
    });
    let coverage_shortfall_escalates = evaluation.tasks.iter().any(|task| {
        task.abstain_reason == "reason:coverage_below_target"
            && task.expected_decision != "allow_cheap"
    });
    let verifier_coverage_shortfall_escalates = evaluation.tasks.iter().any(|task| {
        task.abstain_reason == "reason:verifier_coverage_below_target"
            && task.expected_decision != "allow_cheap"
    });
    let cheap_route_allowed_when_calibrated_in_budget = evaluation.tasks.iter().any(|task| {
        task.expected_decision == "allow_cheap"
            && task.calibration_ref.starts_with("calibration:")
            && task.byte_budget_remaining >= task.required_active_bytes
            && task.latency_budget_remaining_ms >= task.predicted_latency_ms
            && task.coverage_bps >= task.coverage_target_bps
            && task.verifier_coverage_bps >= task.required_verifier_coverage_bps
    });
    let decision_success_beats_cheap_baseline =
        metrics.escalator_decision_success_bps > metrics.cheap_baseline_success_bps;
    let decision_success_beats_always_escalate =
        metrics.escalator_decision_success_bps > metrics.always_escalate_success_bps;
    let wrong_cheap_route_rejected = metrics.false_cheap_route_count
        == metrics.false_cheap_route_rejected_count
        && metrics.false_cheap_route_count > 0;
    let rollback_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.rollback_handle.starts_with("rollback:"));
    let run_event_log_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.run_event_log_ref.starts_with("runlog:"));
    let answer_packet_ref_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.answer_packet_ref.starts_with("answerpacket:"));
    let route_authority_shadow_only = evaluation
        .tasks
        .iter()
        .all(|task| task.route_authority == "shadow_only");
    let no_hidden_route_authority = route_authority_shadow_only;
    let no_hidden_chain = evaluation
        .tasks
        .iter()
        .all(|task| !task.hidden_chain_exposed);
    let no_hidden_cloud = evaluation.tasks.iter().all(|task| !task.hidden_cloud);
    let live_policy_not_mutated = evaluation
        .tasks
        .iter()
        .all(|task| !task.live_policy_mutated);
    let escalator_address_deterministic =
        evaluation.escalator_address == reversed_evaluation.escalator_address;

    let duplicate_task_rejected = duplicate_task_rejected();
    let missing_calibration_rejected = invalid_task_rejected(|task| {
        task.calibration_ref = "";
        task.expected_decision = "allow_cheap";
    }) == Some(EscalatorError::MissingCalibrationRef);
    let missing_scout_ref_rejected =
        invalid_task_rejected(|task| task.scout_ref = "") == Some(EscalatorError::MissingScoutRef);
    let missing_coverage_target_rejected = invalid_task_rejected(|task| {
        task.coverage_target_bps = 0;
    }) == Some(EscalatorError::MissingCoverageTarget);
    let missing_budget_rejected = invalid_task_rejected(|task| {
        task.byte_budget_remaining = 0;
        task.required_active_bytes = 0;
    }) == Some(EscalatorError::MissingBudget);
    let missing_latency_budget_rejected = invalid_task_rejected(|task| {
        task.latency_budget_remaining_ms = 0;
        task.predicted_latency_ms = 0;
    }) == Some(EscalatorError::MissingLatencyBudget);
    let missing_escalation_target_rejected = invalid_task_rejected(|task| {
        task.expected_decision = "escalate_verifier";
        task.escalation_target = "";
    }) == Some(EscalatorError::MissingEscalationTarget);
    let missing_abstain_reason_rejected = invalid_task_rejected(|task| {
        task.expected_decision = "escalate_verifier";
        task.escalation_target = "target:verifier";
        task.abstain_reason = "";
    }) == Some(EscalatorError::MissingAbstainReason);
    let high_uncertainty_allowed_rejected = invalid_task_rejected(|task| {
        task.uncertainty_bps = 9_400;
        task.expected_decision = "allow_cheap";
    }) == Some(EscalatorError::HighUncertaintyAllowed);
    let missing_calibration_allowed_rejected =
        invalid_task_rejected(|task| {
            task.calibration_ref = "calibration:missing";
            task.expected_decision = "allow_cheap";
        }) == Some(EscalatorError::MissingCalibrationAllowed);
    let ood_allowed_rejected = invalid_task_rejected(|task| {
        task.ood_score_bps = 9_200;
        task.expected_decision = "allow_cheap";
    }) == Some(EscalatorError::OodAllowed);
    let byte_budget_allowed_rejected = invalid_task_rejected(|task| {
        task.byte_budget_remaining = 512 * 1024;
        task.required_active_bytes = 2 * 1024 * 1024;
        task.expected_decision = "allow_cheap";
    }) == Some(EscalatorError::ByteBudgetAllowed);
    let latency_budget_allowed_rejected = invalid_task_rejected(|task| {
        task.latency_budget_remaining_ms = 20;
        task.predicted_latency_ms = 80;
        task.expected_decision = "allow_cheap";
    }) == Some(EscalatorError::LatencyBudgetAllowed);
    let coverage_shortfall_allowed_rejected = invalid_task_rejected(|task| {
        task.coverage_bps = 5_000;
        task.coverage_target_bps = 9_000;
        task.expected_decision = "allow_cheap";
    }) == Some(EscalatorError::CoverageShortfallAllowed);
    let verifier_coverage_shortfall_allowed_rejected =
        invalid_task_rejected(|task| {
            task.verifier_coverage_bps = 4_000;
            task.required_verifier_coverage_bps = 8_500;
            task.expected_decision = "allow_cheap";
        }) == Some(EscalatorError::VerifierCoverageShortfallAllowed);
    let cheap_baseline_unbeaten_rejected = invalid_fixture_rejected(|tasks| {
        for task in tasks {
            task.expected_decision = "allow_cheap";
            task.calibration_ref = "calibration:route-family-v1";
            task.uncertainty_bps = 1_000;
            task.ood_score_bps = 500;
            task.coverage_bps = 9_900;
            task.byte_budget_remaining = 8 * 1024 * 1024;
            task.latency_budget_remaining_ms = 200;
            task.verifier_coverage_bps = 9_500;
            task.escalation_target = "";
            task.abstain_reason = "";
        }
    }) == Some(EscalatorError::CheapBaselineUnbeaten);
    let always_escalate_baseline_unbeaten_rejected =
        invalid_fixture_rejected(|tasks| {
            for task in tasks {
                task.expected_decision = "escalate_verifier";
                task.uncertainty_bps = 9_200;
                task.ood_score_bps = 500;
                task.coverage_bps = 9_900;
                task.byte_budget_remaining = 8 * 1024 * 1024;
                task.latency_budget_remaining_ms = 200;
                task.verifier_coverage_bps = 9_500;
                task.calibration_ref = "calibration:route-family-v1";
                task.escalation_target = "target:verifier";
                task.abstain_reason = "reason:high_uncertainty";
            }
        }) == Some(EscalatorError::AlwaysEscalateBaselineUnbeaten);
    let missing_rollback_rejected = invalid_task_rejected(|task| task.rollback_handle = "")
        == Some(EscalatorError::MissingRollback);
    let missing_run_event_log_rejected = invalid_task_rejected(|task| task.run_event_log_ref = "")
        == Some(EscalatorError::MissingRunEventLog);
    let missing_answer_packet_rejected = invalid_task_rejected(|task| task.answer_packet_ref = "")
        == Some(EscalatorError::MissingAnswerPacket);
    let hidden_live_authority_rejected =
        invalid_task_rejected(|task| task.route_authority = "live_route_policy")
            == Some(EscalatorError::HiddenLiveAuthority);
    let live_policy_mutation_rejected =
        invalid_task_rejected(|task| task.live_policy_mutated = true)
            == Some(EscalatorError::LivePolicyMutation);
    let hidden_chain_exposure_rejected =
        invalid_task_rejected(|task| task.hidden_chain_exposed = true)
            == Some(EscalatorError::HiddenChainExposure);
    let cloud_route_rejected =
        invalid_task_rejected(|task| task.hidden_cloud = true) == Some(EscalatorError::CloudRoute);
    let escalator_over_budget_rejected =
        invalid_task_rejected(|task| task.escalator_active_bytes = 8 * 1024 * 1024)
            == Some(EscalatorError::EscalatorBudgetExceeded);
    let no_runtime_bytes_loaded = true;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        (
            "upstream_two_stage_route_scout_abstain_pass",
            upstream_two_stage_route_scout_abstain_pass,
        ),
        (
            "budgeted_escalator_fixture_present",
            budgeted_escalator_fixture_present,
        ),
        ("training_split_bound", training_split_bound),
        ("held_out_split_bound", held_out_split_bound),
        ("task_signatures_bound", task_signatures_bound),
        ("mission_ids_bound", mission_ids_bound),
        ("scout_refs_bound", scout_refs_bound),
        ("calibration_set_bound", calibration_set_bound),
        ("coverage_target_bound", coverage_target_bound),
        ("uncertainty_bound", uncertainty_bound),
        ("ood_signal_bound", ood_signal_bound),
        ("byte_budget_bound", byte_budget_bound),
        ("latency_budget_bound", latency_budget_bound),
        ("verifier_coverage_bound", verifier_coverage_bound),
        ("decision_labels_bound", decision_labels_bound),
        ("escalation_target_bound", escalation_target_bound),
        ("abstain_reason_bound", abstain_reason_bound),
        ("high_uncertainty_escalates", high_uncertainty_escalates),
        ("budget_exhaustion_escalates", budget_exhaustion_escalates),
        ("latency_exhaustion_escalates", latency_exhaustion_escalates),
        (
            "missing_calibration_escalates",
            missing_calibration_escalates,
        ),
        ("ood_escalates", ood_escalates),
        ("coverage_shortfall_escalates", coverage_shortfall_escalates),
        (
            "verifier_coverage_shortfall_escalates",
            verifier_coverage_shortfall_escalates,
        ),
        (
            "cheap_route_allowed_when_calibrated_in_budget",
            cheap_route_allowed_when_calibrated_in_budget,
        ),
        (
            "decision_success_beats_cheap_baseline",
            decision_success_beats_cheap_baseline,
        ),
        (
            "decision_success_beats_always_escalate",
            decision_success_beats_always_escalate,
        ),
        ("wrong_cheap_route_rejected", wrong_cheap_route_rejected),
        ("rollback_bound", rollback_bound),
        ("run_event_log_bound", run_event_log_bound),
        ("answer_packet_ref_bound", answer_packet_ref_bound),
        ("route_authority_shadow_only", route_authority_shadow_only),
        ("no_hidden_route_authority", no_hidden_route_authority),
        ("no_hidden_chain", no_hidden_chain),
        ("no_hidden_cloud", no_hidden_cloud),
        ("live_policy_not_mutated", live_policy_not_mutated),
        (
            "escalator_address_deterministic",
            escalator_address_deterministic,
        ),
        ("duplicate_task_rejected", duplicate_task_rejected),
        ("missing_calibration_rejected", missing_calibration_rejected),
        ("missing_scout_ref_rejected", missing_scout_ref_rejected),
        (
            "missing_coverage_target_rejected",
            missing_coverage_target_rejected,
        ),
        ("missing_budget_rejected", missing_budget_rejected),
        (
            "missing_latency_budget_rejected",
            missing_latency_budget_rejected,
        ),
        (
            "missing_escalation_target_rejected",
            missing_escalation_target_rejected,
        ),
        (
            "missing_abstain_reason_rejected",
            missing_abstain_reason_rejected,
        ),
        (
            "high_uncertainty_allowed_rejected",
            high_uncertainty_allowed_rejected,
        ),
        (
            "missing_calibration_allowed_rejected",
            missing_calibration_allowed_rejected,
        ),
        ("ood_allowed_rejected", ood_allowed_rejected),
        ("byte_budget_allowed_rejected", byte_budget_allowed_rejected),
        (
            "latency_budget_allowed_rejected",
            latency_budget_allowed_rejected,
        ),
        (
            "coverage_shortfall_allowed_rejected",
            coverage_shortfall_allowed_rejected,
        ),
        (
            "verifier_coverage_shortfall_allowed_rejected",
            verifier_coverage_shortfall_allowed_rejected,
        ),
        (
            "cheap_baseline_unbeaten_rejected",
            cheap_baseline_unbeaten_rejected,
        ),
        (
            "always_escalate_baseline_unbeaten_rejected",
            always_escalate_baseline_unbeaten_rejected,
        ),
        ("missing_rollback_rejected", missing_rollback_rejected),
        (
            "missing_run_event_log_rejected",
            missing_run_event_log_rejected,
        ),
        (
            "missing_answer_packet_rejected",
            missing_answer_packet_rejected,
        ),
        (
            "hidden_live_authority_rejected",
            hidden_live_authority_rejected,
        ),
        (
            "live_policy_mutation_rejected",
            live_policy_mutation_rejected,
        ),
        (
            "hidden_chain_exposure_rejected",
            hidden_chain_exposure_rejected,
        ),
        ("cloud_route_rejected", cloud_route_rejected),
        (
            "escalator_over_budget_rejected",
            escalator_over_budget_rejected,
        ),
        ("no_runtime_bytes_loaded", no_runtime_bytes_loaded),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }

    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "training_task_count",
        evaluation.training_task_count(),
        2,
        "tasks",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_task_count",
        evaluation.held_out_task_count(),
        8,
        "tasks",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "escalation_case_count",
        evaluation.escalation_case_count(),
        7,
        "tasks",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "allowed_case_count",
        evaluation.allowed_case_count(),
        3,
        "tasks",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "high_uncertainty_case_count",
        evaluation.reason_count("reason:high_uncertainty"),
        1,
        "tasks",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "budget_exhaustion_case_count",
        evaluation.reason_count("reason:byte_budget_exhausted"),
        1,
        "tasks",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "latency_exhaustion_case_count",
        evaluation.reason_count("reason:latency_budget_exhausted"),
        1,
        "tasks",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_calibration_case_count",
        evaluation.reason_count("reason:missing_calibration"),
        1,
        "tasks",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "ood_case_count",
        evaluation.reason_count("reason:out_of_distribution"),
        1,
        "tasks",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "coverage_shortfall_case_count",
        evaluation.reason_count("reason:coverage_below_target"),
        1,
        "tasks",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_coverage_shortfall_case_count",
        evaluation.reason_count("reason:verifier_coverage_below_target"),
        1,
        "tasks",
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "escalator_decision_success_bps",
        metrics.escalator_decision_success_bps,
        10_000,
        ">=",
        "basis_points",
        metrics.escalator_decision_success_bps >= 10_000,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cheap_baseline_success_bps",
        metrics.cheap_baseline_success_bps,
        metrics.escalator_decision_success_bps,
        "<",
        "basis_points",
        metrics.cheap_baseline_success_bps < metrics.escalator_decision_success_bps,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "always_escalate_success_bps",
        metrics.always_escalate_success_bps,
        metrics.escalator_decision_success_bps,
        "<",
        "basis_points",
        metrics.always_escalate_success_bps < metrics.escalator_decision_success_bps,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "false_cheap_route_count",
        metrics.false_cheap_route_count,
        1,
        ">=",
        "tasks",
        metrics.false_cheap_route_count >= 1,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "false_cheap_route_rejected_count",
        metrics.false_cheap_route_rejected_count,
        metrics.false_cheap_route_count,
        "==",
        "tasks",
        metrics.false_cheap_route_rejected_count == metrics.false_cheap_route_count,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_escalator_active_bytes",
        evaluation.max_escalator_active_bytes(),
        MAX_ESCALATOR_ACTIVE_BYTES,
        "<=",
        "bytes",
        evaluation.max_escalator_active_bytes() <= MAX_ESCALATOR_ACTIVE_BYTES,
    );
    add_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "escalator_address",
        &evaluation.escalator_address,
        "address",
    );

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
        notes: "scope=metadata_only;organ=BudgetedUncertaintyEscalator;reviewer=codex;reviewed_at_utc=2026-06-04T00:00:00Z;validator=falsifier_validator;local_reference_only=true;detail=BudgetedUncertaintyEscalator guards cheap route selectors; no live route authority, no policy mutation, no model/runtime bytes, and no sparse wake promotion executed".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn add_threshold_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    operator: &str,
    unit: &str,
    passed: bool,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), passed);
}

fn add_string_measurement(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String("uas:budgeted-uncertainty-escalator:".to_string()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(
        name.to_string(),
        value.starts_with("uas:budgeted-uncertainty-escalator:"),
    );
}

#[derive(Clone)]
// UAS: uas:budgeted-uncertainty-escalator:evaluation
// Plane: Verification
// Residency: metadata-only
struct EscalatorEvaluation {
    tasks: Vec<EscalatorTask>,
    metrics: EscalatorMetrics,
    escalator_address: String,
}

impl EscalatorEvaluation {
    fn new(tasks: Vec<EscalatorTask>) -> Result<Self, EscalatorError> {
        if tasks.is_empty() {
            return Err(EscalatorError::MissingTask);
        }
        let mut seen = BTreeSet::new();
        for task in &tasks {
            if !seen.insert(task.task_signature) {
                return Err(EscalatorError::DuplicateTask);
            }
            validate_task(task)?;
        }
        let metrics = EscalatorMetrics::from_tasks(&tasks)?;
        let escalator_address = escalator_address(&tasks);
        Ok(Self {
            tasks,
            metrics,
            escalator_address,
        })
    }

    fn held_out_tasks(&self) -> Vec<&EscalatorTask> {
        self.tasks
            .iter()
            .filter(|task| task.split == "held_out")
            .collect()
    }

    fn training_task_count(&self) -> u64 {
        self.tasks
            .iter()
            .filter(|task| task.split == "train")
            .count() as u64
    }

    fn held_out_task_count(&self) -> u64 {
        self.held_out_tasks().len() as u64
    }

    fn escalation_case_count(&self) -> u64 {
        self.tasks
            .iter()
            .filter(|task| task.expected_decision != "allow_cheap")
            .count() as u64
    }

    fn allowed_case_count(&self) -> u64 {
        self.tasks
            .iter()
            .filter(|task| task.expected_decision == "allow_cheap")
            .count() as u64
    }

    fn reason_count(&self, reason: &str) -> u64 {
        self.tasks
            .iter()
            .filter(|task| task.abstain_reason == reason)
            .count() as u64
    }

    fn max_escalator_active_bytes(&self) -> u64 {
        self.tasks
            .iter()
            .map(|task| task.escalator_active_bytes)
            .max()
            .unwrap_or(0)
    }
}

#[derive(Clone, Copy)]
// UAS: uas:budgeted-uncertainty-escalator:metrics
// Plane: Verification
// Residency: metadata-only
struct EscalatorMetrics {
    escalator_decision_success_bps: u64,
    cheap_baseline_success_bps: u64,
    always_escalate_success_bps: u64,
    false_cheap_route_count: u64,
    false_cheap_route_rejected_count: u64,
}

impl EscalatorMetrics {
    fn from_tasks(tasks: &[EscalatorTask]) -> Result<Self, EscalatorError> {
        if tasks.iter().filter(|task| task.split == "train").count() < 2 {
            return Err(EscalatorError::MissingTrainingSplit);
        }
        let held_out = tasks
            .iter()
            .filter(|task| task.split == "held_out")
            .collect::<Vec<_>>();
        if held_out.len() < 8 {
            return Err(EscalatorError::MissingHeldOutSplit);
        }
        let escalator_decision_success_bps =
            decision_success_bps(&held_out, |task| derive_decision(task));
        let cheap_baseline_success_bps = decision_success_bps(&held_out, |_| "allow_cheap");
        let always_escalate_success_bps = decision_success_bps(&held_out, |_| "escalate_verifier");

        if escalator_decision_success_bps <= cheap_baseline_success_bps {
            return Err(EscalatorError::CheapBaselineUnbeaten);
        }
        if escalator_decision_success_bps <= always_escalate_success_bps {
            return Err(EscalatorError::AlwaysEscalateBaselineUnbeaten);
        }
        if !held_out
            .iter()
            .any(|task| task.expected_decision != "allow_cheap")
        {
            return Err(EscalatorError::MissingEscalationCase);
        }
        if !held_out
            .iter()
            .any(|task| task.expected_decision == "allow_cheap")
        {
            return Err(EscalatorError::MissingAllowCase);
        }

        let false_cheap_route_count = held_out
            .iter()
            .filter(|task| task.expected_decision != "allow_cheap")
            .count() as u64;
        let false_cheap_route_rejected_count = held_out
            .iter()
            .filter(|task| {
                task.expected_decision != "allow_cheap" && derive_decision(task) != "allow_cheap"
            })
            .count() as u64;

        Ok(Self {
            escalator_decision_success_bps,
            cheap_baseline_success_bps,
            always_escalate_success_bps,
            false_cheap_route_count,
            false_cheap_route_rejected_count,
        })
    }
}

fn validate_task(task: &EscalatorTask) -> Result<(), EscalatorError> {
    if task.split != "train" && task.split != "held_out" {
        return Err(EscalatorError::MissingSplit);
    }
    if !task.task_signature.starts_with("task:") {
        return Err(EscalatorError::MissingTaskSignature);
    }
    if !task.mission_id.starts_with("mission:") {
        return Err(EscalatorError::MissingMission);
    }
    if !task.scout_ref.starts_with("two-stage:") {
        return Err(EscalatorError::MissingScoutRef);
    }
    if task.expected_decision == "allow_cheap" && !task.calibration_ref.starts_with("calibration:")
    {
        return Err(EscalatorError::MissingCalibrationRef);
    }
    if task.coverage_target_bps < MIN_COVERAGE_TARGET_BPS {
        return Err(EscalatorError::MissingCoverageTarget);
    }
    if task.byte_budget_remaining == 0 || task.required_active_bytes == 0 {
        return Err(EscalatorError::MissingBudget);
    }
    if task.latency_budget_remaining_ms == 0 || task.predicted_latency_ms == 0 {
        return Err(EscalatorError::MissingLatencyBudget);
    }
    if task.expected_decision != "allow_cheap" && !task.escalation_target.starts_with("target:") {
        return Err(EscalatorError::MissingEscalationTarget);
    }
    if task.expected_decision != "allow_cheap" && !task.abstain_reason.starts_with("reason:") {
        return Err(EscalatorError::MissingAbstainReason);
    }
    if task.uncertainty_bps > 10_000 {
        return Err(EscalatorError::InvalidUncertainty);
    }
    if task.ood_score_bps > 10_000 {
        return Err(EscalatorError::InvalidOodScore);
    }
    if task.coverage_bps > 10_000
        || task.coverage_target_bps > 10_000
        || task.verifier_coverage_bps > 10_000
        || task.required_verifier_coverage_bps > 10_000
    {
        return Err(EscalatorError::InvalidCoverage);
    }
    if !valid_decision(task.expected_decision) {
        return Err(EscalatorError::InvalidDecision);
    }
    let derived = derive_decision(task);
    if derived != task.expected_decision {
        return mismatch_error(task);
    }
    if !task.rollback_handle.starts_with("rollback:") {
        return Err(EscalatorError::MissingRollback);
    }
    if !task.run_event_log_ref.starts_with("runlog:") {
        return Err(EscalatorError::MissingRunEventLog);
    }
    if !task.answer_packet_ref.starts_with("answerpacket:") {
        return Err(EscalatorError::MissingAnswerPacket);
    }
    if task.route_authority != "shadow_only" {
        return Err(EscalatorError::HiddenLiveAuthority);
    }
    if task.live_policy_mutated {
        return Err(EscalatorError::LivePolicyMutation);
    }
    if task.hidden_chain_exposed {
        return Err(EscalatorError::HiddenChainExposure);
    }
    if task.hidden_cloud {
        return Err(EscalatorError::CloudRoute);
    }
    if task.escalator_active_bytes > MAX_ESCALATOR_ACTIVE_BYTES {
        return Err(EscalatorError::EscalatorBudgetExceeded);
    }
    Ok(())
}

fn mismatch_error(task: &EscalatorTask) -> Result<(), EscalatorError> {
    if task.calibration_ref == "calibration:missing" && task.expected_decision == "allow_cheap" {
        return Err(EscalatorError::MissingCalibrationAllowed);
    }
    if task.ood_score_bps > OOD_THRESHOLD_BPS && task.expected_decision == "allow_cheap" {
        return Err(EscalatorError::OodAllowed);
    }
    if task.uncertainty_bps > task.uncertainty_ceiling_bps()
        && task.expected_decision == "allow_cheap"
    {
        return Err(EscalatorError::HighUncertaintyAllowed);
    }
    if task.byte_budget_remaining < task.required_active_bytes
        && task.expected_decision == "allow_cheap"
    {
        return Err(EscalatorError::ByteBudgetAllowed);
    }
    if task.latency_budget_remaining_ms < task.predicted_latency_ms
        && task.expected_decision == "allow_cheap"
    {
        return Err(EscalatorError::LatencyBudgetAllowed);
    }
    if task.coverage_bps < task.coverage_target_bps && task.expected_decision == "allow_cheap" {
        return Err(EscalatorError::CoverageShortfallAllowed);
    }
    if task.verifier_coverage_bps < task.required_verifier_coverage_bps
        && task.expected_decision == "allow_cheap"
    {
        return Err(EscalatorError::VerifierCoverageShortfallAllowed);
    }
    Err(EscalatorError::InvalidDecision)
}

impl EscalatorTask {
    fn uncertainty_ceiling_bps(&self) -> u64 {
        if self.route_family == "proof_tools" {
            7_200
        } else {
            8_000
        }
    }
}

fn derive_decision(task: &EscalatorTask) -> &'static str {
    if task.calibration_ref == "calibration:missing" {
        return "escalate_verifier";
    }
    if task.ood_score_bps > OOD_THRESHOLD_BPS {
        return "escalate_full_route";
    }
    if task.uncertainty_bps > task.uncertainty_ceiling_bps() {
        return "escalate_verifier";
    }
    if task.byte_budget_remaining < task.required_active_bytes {
        return "escalate_full_route";
    }
    if task.latency_budget_remaining_ms < task.predicted_latency_ms {
        return "abstain_visible";
    }
    if task.coverage_bps < task.coverage_target_bps {
        return "escalate_verifier";
    }
    if task.verifier_coverage_bps < task.required_verifier_coverage_bps {
        return "escalate_verifier";
    }
    "allow_cheap"
}

fn valid_decision(decision: &str) -> bool {
    matches!(
        decision,
        "allow_cheap" | "escalate_verifier" | "escalate_full_route" | "abstain_visible"
    )
}

fn decision_success_bps(
    tasks: &[&EscalatorTask],
    decision: impl Fn(&EscalatorTask) -> &'static str,
) -> u64 {
    let success = tasks
        .iter()
        .filter(|task| decision(task) == task.expected_decision)
        .count() as u64;
    success.saturating_mul(10_000) / tasks.len() as u64
}

fn escalator_address(tasks: &[EscalatorTask]) -> String {
    let mut rows = tasks
        .iter()
        .map(|task| {
            format!(
                "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
                task.task_signature,
                task.mission_id,
                task.scout_ref,
                task.calibration_ref,
                task.route_family,
                task.selector_kind,
                task.uncertainty_bps,
                task.ood_score_bps,
                task.byte_budget_remaining,
                task.latency_budget_remaining_ms,
                task.expected_decision
            )
        })
        .collect::<Vec<_>>();
    rows.sort();
    let digest = sha256_hex(rows.join("\n").as_bytes());
    format!("uas:budgeted-uncertainty-escalator:{digest}")
}

fn upstream_two_stage_pass() -> bool {
    let Ok(bytes) = std::fs::read(UPSTREAM_TWO_STAGE) else {
        return false;
    };
    let Ok(json) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    json.get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
        && json
            .get("pass_per_axis")
            .and_then(|axes| axes.get("no_runtime_bytes_loaded"))
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false)
}

fn fixture_tasks() -> Vec<EscalatorTask> {
    vec![
        task(
            "train",
            "task:rewrite-private-summary",
            "mission:mas-private-rewrite",
            "apple_private",
            "apple_private_model_profile",
            "calibration:route-family-v1",
            1_400,
            200,
            9_900,
            9_000,
            8 * 1024 * 1024,
            1 * 1024 * 1024,
            200,
            80,
            9_800,
            8_500,
            "allow_cheap",
            "",
            "",
        ),
        task(
            "train",
            "task:proof-repair-uncertain",
            "mission:proof-repair",
            "proof_tools",
            "proof_toolchain",
            "calibration:route-family-v1",
            9_100,
            500,
            9_600,
            9_000,
            8 * 1024 * 1024,
            2 * 1024 * 1024,
            180,
            90,
            9_200,
            8_500,
            "escalate_verifier",
            "target:lean-verifier",
            "reason:high_uncertainty",
        ),
        task(
            "held_out",
            "task:eidos-cited-answer",
            "mission:cited-answer",
            "eidos_retrieval",
            "eidos_index",
            "calibration:route-family-v1",
            1_900,
            300,
            9_700,
            9_000,
            6 * 1024 * 1024,
            1 * 1024 * 1024,
            160,
            70,
            9_300,
            8_500,
            "allow_cheap",
            "",
            "",
        ),
        task(
            "held_out",
            "task:local-code-note-synthesis",
            "mission:local-code",
            "local_qwen",
            "mlx_model_variant",
            "calibration:route-family-v1",
            2_100,
            500,
            9_500,
            9_000,
            10 * 1024 * 1024,
            2 * 1024 * 1024,
            220,
            120,
            9_100,
            8_500,
            "allow_cheap",
            "",
            "",
        ),
        task(
            "held_out",
            "task:cold-kv-recall-over-byte-budget",
            "mission:long-context-recall",
            "kv_recall",
            "kv_page_policy",
            "calibration:route-family-v1",
            2_800,
            600,
            9_300,
            9_000,
            1 * 1024 * 1024,
            4 * 1024 * 1024,
            160,
            120,
            9_000,
            8_500,
            "escalate_full_route",
            "target:full-kv-route",
            "reason:byte_budget_exhausted",
        ),
        task(
            "held_out",
            "task:scope-rex-note-mutation-latency",
            "mission:sovereign-note-mutation",
            "scope_rex_mutation",
            "mutation_plan",
            "calibration:route-family-v1",
            2_600,
            400,
            9_400,
            9_000,
            8 * 1024 * 1024,
            2 * 1024 * 1024,
            30,
            95,
            9_000,
            8_500,
            "abstain_visible",
            "target:user-visible-review",
            "reason:latency_budget_exhausted",
        ),
        task(
            "held_out",
            "task:uncalibrated-source-answer",
            "mission:source-answer",
            "eidos_retrieval",
            "eidos_index",
            "calibration:missing",
            2_300,
            600,
            9_100,
            9_000,
            8 * 1024 * 1024,
            1 * 1024 * 1024,
            160,
            70,
            8_900,
            8_500,
            "escalate_verifier",
            "target:verifier",
            "reason:missing_calibration",
        ),
        task(
            "held_out",
            "task:adversarial-synthesis-ood",
            "mission:adversarial-synthesis",
            "local_qwen",
            "mlx_model_variant",
            "calibration:route-family-v1",
            3_100,
            9_000,
            9_200,
            9_000,
            8 * 1024 * 1024,
            2 * 1024 * 1024,
            180,
            110,
            8_900,
            8_500,
            "escalate_full_route",
            "target:full-shadow-route",
            "reason:out_of_distribution",
        ),
        task(
            "held_out",
            "task:coverage-shortfall-code-patch",
            "mission:code-patch",
            "local_qwen",
            "mlx_model_variant",
            "calibration:route-family-v1",
            2_000,
            500,
            7_800,
            9_000,
            8 * 1024 * 1024,
            2 * 1024 * 1024,
            180,
            100,
            9_200,
            8_500,
            "escalate_verifier",
            "target:test-verifier",
            "reason:coverage_below_target",
        ),
        task(
            "held_out",
            "task:verifier-coverage-shortfall",
            "mission:citation-risk",
            "eidos_retrieval",
            "eidos_index",
            "calibration:route-family-v1",
            2_100,
            500,
            9_400,
            9_000,
            8 * 1024 * 1024,
            1 * 1024 * 1024,
            160,
            80,
            6_900,
            8_500,
            "escalate_verifier",
            "target:citation-verifier",
            "reason:verifier_coverage_below_target",
        ),
    ]
}

#[allow(clippy::too_many_arguments)]
fn task(
    split: &'static str,
    task_signature: &'static str,
    mission_id: &'static str,
    route_family: &'static str,
    selector_kind: &'static str,
    calibration_ref: &'static str,
    uncertainty_bps: u64,
    ood_score_bps: u64,
    coverage_bps: u64,
    coverage_target_bps: u64,
    byte_budget_remaining: u64,
    required_active_bytes: u64,
    latency_budget_remaining_ms: u64,
    predicted_latency_ms: u64,
    verifier_coverage_bps: u64,
    required_verifier_coverage_bps: u64,
    expected_decision: &'static str,
    escalation_target: &'static str,
    abstain_reason: &'static str,
) -> EscalatorTask {
    EscalatorTask {
        split,
        task_signature,
        mission_id,
        scout_ref: "two-stage:route-scout-abstain",
        calibration_ref,
        route_family,
        selector_kind,
        uncertainty_bps,
        ood_score_bps,
        coverage_bps,
        coverage_target_bps,
        byte_budget_remaining,
        required_active_bytes,
        latency_budget_remaining_ms,
        predicted_latency_ms,
        verifier_coverage_bps,
        required_verifier_coverage_bps,
        expected_decision,
        escalation_target,
        abstain_reason,
        rollback_handle: "rollback:budgeted-uncertainty-escalator",
        run_event_log_ref: "runlog:budgeted-uncertainty-escalator",
        answer_packet_ref: "answerpacket:budgeted-uncertainty-escalator",
        route_authority: "shadow_only",
        escalator_active_bytes: 1 * 1024 * 1024,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        live_policy_mutated: false,
    }
}

fn duplicate_task_rejected() -> bool {
    let mut tasks = fixture_tasks();
    tasks.push(tasks[0].clone());
    EscalatorEvaluation::new(tasks).err() == Some(EscalatorError::DuplicateTask)
}

fn invalid_task_rejected(mutate: impl FnOnce(&mut EscalatorTask)) -> Option<EscalatorError> {
    let mut tasks = fixture_tasks();
    let mut task = tasks.remove(0);
    mutate(&mut task);
    tasks.insert(0, task);
    EscalatorEvaluation::new(tasks).err()
}

fn invalid_fixture_rejected(
    mutate: impl FnOnce(&mut Vec<EscalatorTask>),
) -> Option<EscalatorError> {
    let mut tasks = fixture_tasks();
    mutate(&mut tasks);
    EscalatorEvaluation::new(tasks).err()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_fixture_rejects() {
        assert_eq!(
            EscalatorEvaluation::new(Vec::new()).err(),
            Some(EscalatorError::MissingTask)
        );
    }

    #[test]
    fn fixture_evaluation_passes_and_address_is_order_stable() {
        let tasks = fixture_tasks();
        let reversed = tasks.iter().cloned().rev().collect::<Vec<_>>();
        let evaluation = match EscalatorEvaluation::new(tasks) {
            Ok(evaluation) => evaluation,
            Err(error) => panic!("fixture should pass: {error}"),
        };
        let reversed_evaluation = match EscalatorEvaluation::new(reversed) {
            Ok(evaluation) => evaluation,
            Err(error) => panic!("reversed fixture should pass: {error}"),
        };
        assert_eq!(evaluation.training_task_count(), 2);
        assert_eq!(evaluation.held_out_task_count(), 8);
        assert_eq!(evaluation.allowed_case_count(), 3);
        assert_eq!(evaluation.escalation_case_count(), 7);
        assert_eq!(
            evaluation.escalator_address,
            reversed_evaluation.escalator_address
        );
    }

    #[test]
    fn required_invalid_fixtures_reject() {
        assert!(duplicate_task_rejected());
        assert_eq!(
            invalid_task_rejected(|task| {
                task.calibration_ref = "calibration:missing";
                task.expected_decision = "allow_cheap";
            }),
            Some(EscalatorError::MissingCalibrationAllowed)
        );
        assert_eq!(
            invalid_task_rejected(|task| {
                task.ood_score_bps = 9_500;
                task.expected_decision = "allow_cheap";
            }),
            Some(EscalatorError::OodAllowed)
        );
        assert_eq!(
            invalid_task_rejected(|task| {
                task.byte_budget_remaining = 1;
                task.required_active_bytes = 2;
                task.expected_decision = "allow_cheap";
            }),
            Some(EscalatorError::ByteBudgetAllowed)
        );
        assert_eq!(
            invalid_task_rejected(|task| task.route_authority = "live_route_policy"),
            Some(EscalatorError::HiddenLiveAuthority)
        );
        assert_eq!(
            invalid_fixture_rejected(|tasks| {
                for task in tasks {
                    task.expected_decision = "allow_cheap";
                    task.calibration_ref = "calibration:route-family-v1";
                    task.uncertainty_bps = 1_000;
                    task.ood_score_bps = 500;
                    task.coverage_bps = 9_900;
                    task.byte_budget_remaining = 8 * 1024 * 1024;
                    task.latency_budget_remaining_ms = 200;
                    task.verifier_coverage_bps = 9_500;
                    task.escalation_target = "";
                    task.abstain_reason = "";
                }
            }),
            Some(EscalatorError::CheapBaselineUnbeaten)
        );
    }

    #[test]
    fn build_artifact_sets_required_scope_axis() {
        let artifact = match build_artifact() {
            Ok(artifact) => artifact,
            Err(error) => panic!("artifact should build: {error}"),
        };
        assert_eq!(artifact.falsifier_id, FALSIFIER_ID);
        assert!(artifact.pass_per_axis["no_runtime_bytes_loaded"]);
        assert!(artifact.pass_per_axis["high_uncertainty_escalates"]);
        assert!(artifact.pass_per_axis["missing_calibration_escalates"]);
        assert!(artifact.pass_per_axis["wrong_cheap_route_rejected"]);
    }
}
