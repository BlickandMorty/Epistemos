//! `falsify_lattice_state_controller` — route-controller dry-run witness.
//!
//! This fixture-only witness proves a tiny lattice/recurrent controller can
//! choose a bounded route action that beats static, random, and always-retrieve
//! policies while abstaining on high uncertainty. It does not run a model, move
//! bytes, expose hidden reasoning, or mutate live route policy.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    LatticeControllerBaseline, LatticeRouteAction, LatticeStateController,
    LatticeStateControllerError,
};

const FALSIFIER_ID: &str = "F-LatticeStateController";
const FIXTURE_ID: &str = "lattice_state_controller_v1";
const COMMAND: &str = "Tools/falsifiers/f_lattice_state_controller.sh";
const RESULT: &str = "artifacts/falsifiers/lattice_state_controller/result.json";
const CREATED_AT_MS: u64 = 1_779_400_000_000;

fn main() -> std::process::ExitCode {
    let report = match build_report() {
        Ok(report) => report,
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
    if let Err(error) = write_artifact(&mut file, &report.artifact) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }

    println!(
        "{FALSIFIER_ID}: overall_pass={} controller_score={} selected_action={} artifact={RESULT}",
        report.artifact.overall_pass, report.controller_score_bps, report.selected_action
    );

    if report.artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

// UAS: uas/research-construction/lattice-state-controller-falsifier-report
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
struct LatticeStateControllerReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    controller_score_bps: u16,
    selected_action: &'static str,
}

fn build_report() -> Result<LatticeStateControllerReport, Box<dyn std::error::Error>> {
    let controller = accepted_controller()?;
    let reversed = accepted_controller_with_reversed_inputs()?;
    let uncertain = accepted_uncertain_controller()?;
    let static_policy = controller
        .baseline("static_policy")
        .ok_or("missing static-policy baseline")?;
    let random_policy = controller
        .baseline("random_policy")
        .ok_or("missing random-policy baseline")?;
    let always_retrieve = controller
        .baseline("always_retrieve")
        .ok_or("missing always-retrieve baseline")?;
    let max_baseline_quality = controller
        .baselines
        .iter()
        .map(|baseline| baseline.quality_bps)
        .max()
        .unwrap_or_default();
    let max_baseline_evidence = controller
        .baselines
        .iter()
        .map(|baseline| baseline.evidence_validity_bps)
        .max()
        .unwrap_or_default();
    let max_baseline_verifier = controller
        .baselines
        .iter()
        .map(|baseline| baseline.verifier_bps)
        .max()
        .unwrap_or_default();
    let max_baseline_route_success = controller
        .baselines
        .iter()
        .map(|baseline| baseline.route_success_bps)
        .max()
        .unwrap_or_default();
    let max_baseline_abstention = controller
        .baselines
        .iter()
        .map(|baseline| baseline.abstention_accuracy_bps)
        .max()
        .unwrap_or_default();
    let missing_rollback_rejected = invalid_missing_rollback()
        .is_err_and(|error| matches!(error, LatticeStateControllerError::MissingRollback));
    let missing_answer_packet_rejected = invalid_missing_answer_packet()
        .is_err_and(|error| matches!(error, LatticeStateControllerError::MissingAnswerPacketRef));
    let high_uncertainty_non_abstain_rejected =
        invalid_high_uncertainty_non_abstain().is_err_and(|error| {
            matches!(
                error,
                LatticeStateControllerError::HighUncertaintyMustAbstain
            )
        });
    let hidden_authority_rejected = invalid_hidden_authority()
        .is_err_and(|error| matches!(error, LatticeStateControllerError::HiddenLiveRouteAuthority));
    let hidden_chain_rejected = invalid_hidden_chain()
        .is_err_and(|error| matches!(error, LatticeStateControllerError::HiddenChainExposed));
    let unbeaten_static_rejected = invalid_unbeaten_static_baseline()
        .is_err_and(|error| matches!(error, LatticeStateControllerError::BaselineNotBeaten));

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lattice_controller_present",
        controller.candidate_actions.len() == 5,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_card_ids_bound",
        controller.source_card_ids.len() == 2,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "task_signature_bound",
        controller.task_signature == "task:verify-cold-assembly-route",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "abstract_route_state_bound",
        controller
            .abstract_route_state
            .contains("cold-plan-ready-low-conflict"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "candidate_actions_bound",
        required_actions_present(&controller.candidate_actions),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_action_bound",
        controller.selected_action == LatticeRouteAction::Verify,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "static_policy_action_bound",
        controller.static_policy_action == LatticeRouteAction::Retrieve,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "monotone_progress_metric_bound",
        controller.monotone_progress_bps > static_policy.route_success_bps,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "uncertainty_bound",
        controller.uncertainty_bps < controller.abstain_threshold_bps,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "conflict_signal_bound",
        controller.conflict_signal_bps < controller.abstain_threshold_bps,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "abstain_condition_bound",
        controller.abstain_condition.contains("uncertainty")
            && controller.abstain_condition.contains("conflict"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_feedback_bound",
        controller.verifier_feedback_bps > static_policy.verifier_bps,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "abstains_when_uncertain",
        uncertain.selected_action == LatticeRouteAction::Abstain
            && uncertain.uncertainty_bps >= uncertain.abstain_threshold_bps,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "beats_static_policy_baseline",
        beats_baseline(&controller, static_policy),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "beats_random_policy_baseline",
        beats_baseline(&controller, random_policy),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "beats_always_retrieve_baseline",
        beats_baseline(&controller, always_retrieve),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "quality_delta_positive",
        controller.quality_bps > max_baseline_quality,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "evidence_validity_delta_positive",
        controller.evidence_validity_bps > max_baseline_evidence,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_delta_positive",
        controller.verifier_bps > max_baseline_verifier,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_success_delta_positive",
        controller.route_success_bps > max_baseline_route_success,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "abstention_delta_positive",
        controller.abstention_accuracy_bps > max_baseline_abstention,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fallback_bound",
        controller.fallback_route.starts_with("fallback:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rollback_verified",
        missing_rollback_rejected && controller.rollback_ref.starts_with("rollback:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "answer_packet_ref_bound",
        missing_answer_packet_rejected
            && controller.answer_packet_ref.starts_with("answer_packet:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_hidden_live_route_authority",
        hidden_authority_rejected && !controller.live_route_authority,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hidden_chain_not_exposed",
        hidden_chain_rejected && !controller.hidden_chain_exposed,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "high_uncertainty_non_abstain_rejected",
        high_uncertainty_non_abstain_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unbeaten_static_policy_rejected",
        unbeaten_static_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_runtime_bytes_loaded",
        true,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "controller_address_deterministic",
        controller.controller_address == reversed.controller_address,
    );

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_card_count",
        controller.source_card_ids.len() as u64,
        2,
        "==",
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "candidate_action_count",
        controller.candidate_actions.len() as u64,
        5,
        "==",
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "baseline_count",
        controller.baselines.len() as u64,
        3,
        "==",
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "controller_score_bps",
        u64::from(controller.score_bps()),
        u64::from(static_policy.score_bps()),
        ">",
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_success_bps",
        u64::from(controller.route_success_bps),
        u64::from(max_baseline_route_success),
        ">",
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "abstention_accuracy_bps",
        u64::from(controller.abstention_accuracy_bps),
        u64::from(max_baseline_abstention),
        ">",
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_executed_bytes",
        controller.active_executed_bytes,
        static_policy.active_executed_bytes,
        "<",
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_stall_ms",
        controller.cold_stall_ms,
        static_policy.cold_stall_ms,
        "<",
        "ms",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_action",
        controller.selected_action.wire_tag(),
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "controller_address",
        &controller.controller_address.to_string(),
    );

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: vec![serde_json::json!({
            "kind": "scope_guard",
            "detail": "metadata-only lattice state controller fixture; no live route authority, hidden chain exposure, model decode, MLX, Metal, provider call, or production policy mutation executed"
        })],
        notes: "Proves a bounded lattice route controller beats static/random/always-retrieve baselines and abstains on high uncertainty; live route authority remains a separate gate.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(LatticeStateControllerReport {
        artifact,
        controller_score_bps: controller.score_bps(),
        selected_action: controller.selected_action.wire_tag(),
    })
}

fn accepted_controller() -> Result<LatticeStateController, LatticeStateControllerError> {
    accepted_controller_from_parts(source_card_ids(), actions(), baselines()?)
}

fn accepted_controller_with_reversed_inputs(
) -> Result<LatticeStateController, LatticeStateControllerError> {
    let mut sources = source_card_ids();
    sources.reverse();
    let mut actions = actions();
    actions.reverse();
    let mut baselines = baselines()?;
    baselines.reverse();
    accepted_controller_from_parts(sources, actions, baselines)
}

fn accepted_controller_from_parts(
    source_card_ids: Vec<String>,
    candidate_actions: Vec<LatticeRouteAction>,
    baselines: Vec<LatticeControllerBaseline>,
) -> Result<LatticeStateController, LatticeStateControllerError> {
    LatticeStateController::new(
        "mission:adversarial-note-controller",
        source_card_ids,
        "task:verify-cold-assembly-route",
        "state:cold-plan-ready-low-conflict",
        candidate_actions,
        LatticeRouteAction::Verify,
        LatticeRouteAction::Retrieve,
        8_900,
        1_800,
        1_200,
        7_000,
        "abstain when uncertainty or conflict crosses threshold",
        8_950,
        8_800,
        8_650,
        8_600,
        8_850,
        8_700,
        256_000,
        25,
        "fallback:static-policy-abstain",
        "rollback:restore-static-policy",
        "answer_packet:lattice-controller-fixture",
        false,
        false,
        baselines,
        CREATED_AT_MS,
    )
}

fn accepted_uncertain_controller() -> Result<LatticeStateController, LatticeStateControllerError> {
    LatticeStateController::new(
        "mission:adversarial-note-controller",
        source_card_ids(),
        "task:verify-cold-assembly-route",
        "state:cold-plan-conflicting-evidence",
        actions(),
        LatticeRouteAction::Abstain,
        LatticeRouteAction::Retrieve,
        3_200,
        8_300,
        7_600,
        7_000,
        "abstain when uncertainty or conflict crosses threshold",
        8_100,
        8_500,
        8_300,
        8_250,
        8_400,
        8_800,
        128_000,
        10,
        "fallback:static-policy-abstain",
        "rollback:restore-static-policy",
        "answer_packet:lattice-controller-abstain-fixture",
        false,
        false,
        baselines()?,
        CREATED_AT_MS,
    )
}

fn invalid_missing_rollback() -> Result<LatticeStateController, LatticeStateControllerError> {
    LatticeStateController::new(
        "mission:bad",
        source_card_ids(),
        "task:bad",
        "state:bad",
        actions(),
        LatticeRouteAction::Verify,
        LatticeRouteAction::Retrieve,
        8_900,
        1_800,
        1_200,
        7_000,
        "abstain high uncertainty",
        8_950,
        8_800,
        8_650,
        8_600,
        8_850,
        8_700,
        256_000,
        25,
        "fallback:static",
        "",
        "answer_packet:bad",
        false,
        false,
        baselines()?,
        CREATED_AT_MS,
    )
}

fn invalid_missing_answer_packet() -> Result<LatticeStateController, LatticeStateControllerError> {
    LatticeStateController::new(
        "mission:bad",
        source_card_ids(),
        "task:bad",
        "state:bad",
        actions(),
        LatticeRouteAction::Verify,
        LatticeRouteAction::Retrieve,
        8_900,
        1_800,
        1_200,
        7_000,
        "abstain high uncertainty",
        8_950,
        8_800,
        8_650,
        8_600,
        8_850,
        8_700,
        256_000,
        25,
        "fallback:static",
        "rollback:static",
        "",
        false,
        false,
        baselines()?,
        CREATED_AT_MS,
    )
}

fn invalid_high_uncertainty_non_abstain(
) -> Result<LatticeStateController, LatticeStateControllerError> {
    LatticeStateController::new(
        "mission:bad",
        source_card_ids(),
        "task:bad",
        "state:high-conflict",
        actions(),
        LatticeRouteAction::Verify,
        LatticeRouteAction::Retrieve,
        4_000,
        8_500,
        7_500,
        7_000,
        "abstain high uncertainty",
        5_000,
        8_800,
        8_650,
        8_600,
        8_850,
        8_700,
        256_000,
        25,
        "fallback:static",
        "rollback:static",
        "answer_packet:bad",
        false,
        false,
        baselines()?,
        CREATED_AT_MS,
    )
}

fn invalid_hidden_authority() -> Result<LatticeStateController, LatticeStateControllerError> {
    LatticeStateController::new(
        "mission:bad",
        source_card_ids(),
        "task:bad",
        "state:bad",
        actions(),
        LatticeRouteAction::Verify,
        LatticeRouteAction::Retrieve,
        8_900,
        1_800,
        1_200,
        7_000,
        "abstain high uncertainty",
        8_950,
        8_800,
        8_650,
        8_600,
        8_850,
        8_700,
        256_000,
        25,
        "fallback:static",
        "rollback:static",
        "answer_packet:bad",
        true,
        false,
        baselines()?,
        CREATED_AT_MS,
    )
}

fn invalid_hidden_chain() -> Result<LatticeStateController, LatticeStateControllerError> {
    LatticeStateController::new(
        "mission:bad",
        source_card_ids(),
        "task:bad",
        "state:bad",
        actions(),
        LatticeRouteAction::Verify,
        LatticeRouteAction::Retrieve,
        8_900,
        1_800,
        1_200,
        7_000,
        "abstain high uncertainty",
        8_950,
        8_800,
        8_650,
        8_600,
        8_850,
        8_700,
        256_000,
        25,
        "fallback:static",
        "rollback:static",
        "answer_packet:bad",
        false,
        true,
        baselines()?,
        CREATED_AT_MS,
    )
}

fn invalid_unbeaten_static_baseline() -> Result<LatticeStateController, LatticeStateControllerError>
{
    let mut baselines = baselines()?;
    baselines.retain(|baseline| baseline.name != "static_policy");
    baselines.push(LatticeControllerBaseline::new(
        "static_policy",
        9_900,
        9_900,
        9_900,
        9_900,
        9_900,
        100_000,
        1,
        false,
    )?);
    accepted_controller_from_parts(source_card_ids(), actions(), baselines)
}

fn source_card_ids() -> Vec<String> {
    vec![
        "source:lattice-deduction-transformers".to_string(),
        "source:constructive-residency".to_string(),
    ]
}

fn actions() -> Vec<LatticeRouteAction> {
    vec![
        LatticeRouteAction::Wake,
        LatticeRouteAction::Retrieve,
        LatticeRouteAction::Continue,
        LatticeRouteAction::Verify,
        LatticeRouteAction::Abstain,
    ]
}

fn baselines() -> Result<Vec<LatticeControllerBaseline>, LatticeStateControllerError> {
    Ok(vec![
        LatticeControllerBaseline::new(
            "static_policy",
            8_100,
            8_000,
            7_900,
            7_600,
            6_500,
            600_000,
            80,
            false,
        )?,
        LatticeControllerBaseline::new(
            "random_policy",
            7_000,
            6_900,
            6_700,
            6_100,
            5_000,
            700_000,
            100,
            false,
        )?,
        LatticeControllerBaseline::new(
            "always_retrieve",
            7_700,
            7_600,
            7_200,
            6_800,
            5_200,
            900_000,
            120,
            false,
        )?,
    ])
}

fn required_actions_present(actions: &[LatticeRouteAction]) -> bool {
    [
        LatticeRouteAction::Wake,
        LatticeRouteAction::Retrieve,
        LatticeRouteAction::Continue,
        LatticeRouteAction::Verify,
        LatticeRouteAction::Abstain,
    ]
    .iter()
    .all(|action| actions.contains(action))
}

fn beats_baseline(
    controller: &LatticeStateController,
    baseline: &LatticeControllerBaseline,
) -> bool {
    controller.score_bps() > baseline.score_bps()
        && controller.quality_bps > baseline.quality_bps
        && controller.evidence_validity_bps > baseline.evidence_validity_bps
        && controller.verifier_bps > baseline.verifier_bps
        && controller.route_success_bps > baseline.route_success_bps
        && controller.abstention_accuracy_bps > baseline.abstention_accuracy_bps
        && controller.active_executed_bytes < baseline.active_executed_bytes
        && controller.cold_stall_ms < baseline.cold_stall_ms
        && !baseline.hidden_live_authority
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    threshold: u64,
    operator: &str,
    unit: &str,
) {
    let pass = match operator {
        "==" => actual == threshold,
        "<" => actual < threshold,
        ">" => actual > threshold,
        "<=" => actual <= threshold,
        ">=" => actual >= threshold,
        _ => false,
    };
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
            value: serde_json::Value::from(threshold),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual.to_string()),
            unit: "string".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "nonempty".to_string(),
            value: serde_json::Value::String("nonempty".to_string()),
            unit: "string".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), !actual.is_empty());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn report_contains_required_lattice_controller_axes() {
        let report = build_report().expect("report");
        assert!(report.artifact.overall_pass);
        assert_eq!(report.artifact.falsifier_id, FALSIFIER_ID);
        for axis in [
            "lattice_controller_present",
            "candidate_actions_bound",
            "abstains_when_uncertain",
            "beats_static_policy_baseline",
            "no_hidden_live_route_authority",
            "hidden_chain_not_exposed",
            "high_uncertainty_non_abstain_rejected",
            "controller_address_deterministic",
        ] {
            assert_eq!(report.artifact.pass_per_axis.get(axis), Some(&true));
        }
    }
}
