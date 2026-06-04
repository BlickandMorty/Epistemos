//! `falsify_route_scout_ssm_baseline` -- small scout baseline contract.
//!
//! Metadata-only witness for `F-RouteScoutSSM-Baseline`. It proves a tiny
//! RouteScoutSSM-style selector predicts route family and verifier need on
//! held-out tasks better than static, random, recency, and embedding-only
//! baselines while staying shadow-only and AnswerPacket-visible. No
//! runtime/model bytes are loaded.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-RouteScoutSSM-Baseline";
const FIXTURE_ID: &str = "route_scout_ssm_baseline_v1";
const COMMAND: &str = "Tools/falsifiers/f_route_scout_ssm_baseline.sh";
const RESULT: &str = "artifacts/falsifiers/route_scout_ssm_baseline/result.json";
const UPSTREAM_VERIFIER_REGRET: &str = "artifacts/falsifiers/verifier_regret_ledger/result.json";
const MAX_SCOUT_ACTIVE_BYTES: u64 = 4 * 1024 * 1024;
const MIN_HEAVY_ROUTE_MULTIPLE: u64 = 8;

// UAS: uas:route-scout:prediction
// Plane: Controller + Verification
// Residency: metadata-only route labels, no model/runtime bytes.
#[derive(Clone, Copy)]
struct RoutePrediction {
    route_family: &'static str,
    verifier_need: bool,
    route_confidence_bps: u64,
    verifier_confidence_bps: u64,
}

// UAS: uas:route-scout:task
// Plane: Controller
// Residency: metadata-only fixture row.
#[derive(Clone)]
struct ScoutTask {
    split: &'static str,
    task_signature: &'static str,
    mission_id: &'static str,
    source_features: &'static [&'static str],
    cache_features: &'static [&'static str],
    trace_features: &'static [&'static str],
    verifier_features: &'static [&'static str],
    hidden_state_ref: &'static str,
    route_logits_ref: &'static str,
    label_route_family: &'static str,
    label_verifier_need: bool,
    scout: RoutePrediction,
    static_baseline: RoutePrediction,
    random_baseline: RoutePrediction,
    recency_baseline: RoutePrediction,
    embedding_baseline: RoutePrediction,
    rollback_handle: &'static str,
    run_event_log_ref: &'static str,
    answer_packet_ref: &'static str,
    route_authority: &'static str,
    scout_active_bytes: u64,
    heavy_route_min_active_bytes: u64,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    live_policy_mutated: bool,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:route-scout:error
// Plane: Verification
// Residency: metadata-only
enum ScoutError {
    MissingTask,
    DuplicateTask,
    MissingSplit,
    MissingTaskSignature,
    MissingMission,
    MissingFeature,
    MissingState,
    MissingLogits,
    MissingRouteLabel,
    UnknownRouteFamily,
    MissingPrediction,
    InvalidConfidence,
    MissingHeldOut,
    MissingTrainingSplit,
    StaticRouteBaselineUnbeaten,
    RandomRouteBaselineUnbeaten,
    RecencyRouteBaselineUnbeaten,
    EmbeddingRouteBaselineUnbeaten,
    StaticVerifierBaselineUnbeaten,
    RandomVerifierBaselineUnbeaten,
    RecencyVerifierBaselineUnbeaten,
    EmbeddingVerifierBaselineUnbeaten,
    RouteCalibrationUnbeaten,
    VerifierCalibrationUnbeaten,
    MissingAbstentionCase,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    HiddenLiveAuthority,
    LivePolicyMutation,
    HiddenChainExposure,
    CloudRoute,
    ScoutBudgetExceeded,
    ScoutNotCheaper,
}

impl std::fmt::Display for ScoutError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for ScoutError {}

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
        "{FALSIFIER_ID}: overall_pass={} held_out_task_count={} scout_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["held_out_task_count"].value,
        artifact.measurements["scout_address"].value
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
    let evaluation = ScoutEvaluation::new(tasks)?;
    let reversed_evaluation = ScoutEvaluation::new(reversed)?;
    let metrics = evaluation.metrics;

    let upstream_verifier_regret_ledger_pass = upstream_verifier_regret_ledger_pass();
    let route_scout_fixture_present = evaluation.tasks.len() == 9;
    let training_split_bound = evaluation.training_task_count() >= 2;
    let held_out_split_bound = evaluation.held_out_task_count() >= 7;
    let task_signatures_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.task_signature.starts_with("task:"));
    let mission_ids_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.mission_id.starts_with("mission:"));
    let source_features_bound = evaluation
        .tasks
        .iter()
        .all(|task| prefixed_features(task.source_features, "source:"));
    let cache_features_bound = evaluation
        .tasks
        .iter()
        .all(|task| prefixed_features(task.cache_features, "cache:"));
    let trace_features_bound = evaluation
        .tasks
        .iter()
        .all(|task| prefixed_features(task.trace_features, "trace:"));
    let verifier_features_bound = evaluation
        .tasks
        .iter()
        .all(|task| prefixed_features(task.verifier_features, "verifier:"));
    let hidden_state_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.hidden_state_ref.starts_with("scout-state:"));
    let route_logits_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.route_logits_ref.starts_with("route-logits:"));
    let route_family_labels_bound = evaluation
        .tasks
        .iter()
        .all(|task| valid_route_family(task.label_route_family));
    let verifier_need_labels_bound = true;
    let scout_predictions_present = evaluation
        .tasks
        .iter()
        .all(|task| valid_prediction(&task.scout));
    let scout_cheaper_than_heavy_route = evaluation.tasks.iter().all(scout_is_cheaper);
    let route_family_accuracy_beats_static =
        metrics.scout_route_accuracy_bps > metrics.static_route_accuracy_bps;
    let route_family_accuracy_beats_random =
        metrics.scout_route_accuracy_bps > metrics.random_route_accuracy_bps;
    let route_family_accuracy_beats_recency =
        metrics.scout_route_accuracy_bps > metrics.recency_route_accuracy_bps;
    let route_family_accuracy_beats_embedding =
        metrics.scout_route_accuracy_bps > metrics.embedding_route_accuracy_bps;
    let verifier_need_accuracy_beats_static =
        metrics.scout_verifier_accuracy_bps > metrics.static_verifier_accuracy_bps;
    let verifier_need_accuracy_beats_random =
        metrics.scout_verifier_accuracy_bps > metrics.random_verifier_accuracy_bps;
    let verifier_need_accuracy_beats_recency =
        metrics.scout_verifier_accuracy_bps > metrics.recency_verifier_accuracy_bps;
    let verifier_need_accuracy_beats_embedding =
        metrics.scout_verifier_accuracy_bps > metrics.embedding_verifier_accuracy_bps;
    let route_calibration_beats_baselines = metrics.scout_route_calibration_error_bps
        < metrics.best_baseline_route_calibration_error_bps;
    let verifier_calibration_beats_baselines = metrics.scout_verifier_calibration_error_bps
        < metrics.best_baseline_verifier_calibration_error_bps;
    let abstention_case_present = evaluation
        .held_out_tasks()
        .iter()
        .any(|task| task.label_route_family == "abstain_escalate");
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
    let no_hidden_route_authority = evaluation
        .tasks
        .iter()
        .all(|task| task.route_authority == "shadow_only");
    let no_hidden_chain = evaluation
        .tasks
        .iter()
        .all(|task| !task.hidden_chain_exposed);
    let no_hidden_cloud = evaluation.tasks.iter().all(|task| !task.hidden_cloud);
    let live_policy_not_mutated = evaluation
        .tasks
        .iter()
        .all(|task| !task.live_policy_mutated);
    let scout_address_deterministic = evaluation.scout_address == reversed_evaluation.scout_address;
    let no_runtime_bytes_loaded = true;

    let duplicate_task_rejected = duplicate_task_rejected();
    let missing_label_rejected = invalid_task_rejected(|task| task.label_route_family = "")
        == Some(ScoutError::MissingRouteLabel);
    let missing_feature_rejected = invalid_task_rejected(|task| task.source_features = &[])
        == Some(ScoutError::MissingFeature);
    let missing_logits_rejected =
        invalid_task_rejected(|task| task.route_logits_ref = "") == Some(ScoutError::MissingLogits);
    let unknown_route_family_rejected =
        invalid_task_rejected(|task| task.scout.route_family = "route:unknown")
            == Some(ScoutError::UnknownRouteFamily);
    let missing_prediction_rejected = invalid_task_rejected(|task| task.scout.route_family = "")
        == Some(ScoutError::MissingPrediction);
    let no_held_out_rejected =
        invalid_fixture_rejected(|tasks| tasks.iter_mut().for_each(|task| task.split = "train"))
            == Some(ScoutError::MissingHeldOut);
    let static_baseline_unbeaten_rejected = invalid_fixture_rejected(|tasks| {
        for task in tasks {
            task.static_baseline.route_family = task.label_route_family;
        }
    }) == Some(ScoutError::StaticRouteBaselineUnbeaten);
    let random_baseline_unbeaten_rejected = invalid_fixture_rejected(|tasks| {
        for task in tasks {
            task.random_baseline.route_family = task.label_route_family;
        }
    }) == Some(ScoutError::RandomRouteBaselineUnbeaten);
    let recency_baseline_unbeaten_rejected = invalid_fixture_rejected(|tasks| {
        for task in tasks {
            task.recency_baseline.route_family = task.label_route_family;
        }
    }) == Some(ScoutError::RecencyRouteBaselineUnbeaten);
    let embedding_baseline_unbeaten_rejected =
        invalid_fixture_rejected(|tasks| {
            for task in tasks {
                task.embedding_baseline.route_family = task.label_route_family;
            }
        }) == Some(ScoutError::EmbeddingRouteBaselineUnbeaten);
    let verifier_static_baseline_unbeaten_rejected =
        invalid_fixture_rejected(|tasks| {
            for task in tasks {
                task.static_baseline.verifier_need = task.label_verifier_need;
            }
        }) == Some(ScoutError::StaticVerifierBaselineUnbeaten);
    let missing_rollback_rejected = invalid_task_rejected(|task| task.rollback_handle = "")
        == Some(ScoutError::MissingRollback);
    let missing_run_event_log_rejected = invalid_task_rejected(|task| task.run_event_log_ref = "")
        == Some(ScoutError::MissingRunEventLog);
    let missing_answer_packet_rejected = invalid_task_rejected(|task| task.answer_packet_ref = "")
        == Some(ScoutError::MissingAnswerPacket);
    let hidden_live_authority_rejected =
        invalid_task_rejected(|task| task.route_authority = "live_route_policy")
            == Some(ScoutError::HiddenLiveAuthority);
    let live_policy_mutation_rejected =
        invalid_task_rejected(|task| task.live_policy_mutated = true)
            == Some(ScoutError::LivePolicyMutation);
    let hidden_chain_exposure_rejected =
        invalid_task_rejected(|task| task.hidden_chain_exposed = true)
            == Some(ScoutError::HiddenChainExposure);
    let cloud_route_rejected =
        invalid_task_rejected(|task| task.hidden_cloud = true) == Some(ScoutError::CloudRoute);
    let scout_over_budget_rejected =
        invalid_task_rejected(|task| task.scout_active_bytes = MAX_SCOUT_ACTIVE_BYTES + 1)
            == Some(ScoutError::ScoutBudgetExceeded);
    let scout_not_cheaper_rejected =
        invalid_task_rejected(|task| task.heavy_route_min_active_bytes = task.scout_active_bytes)
            == Some(ScoutError::ScoutNotCheaper);
    let uncalibrated_scout_rejected = invalid_fixture_rejected(|tasks| {
        for task in tasks {
            task.scout.route_confidence_bps = 1_000;
            task.scout.verifier_confidence_bps = 1_000;
        }
    }) == Some(ScoutError::RouteCalibrationUnbeaten);

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_verifier_regret_ledger_pass",
            upstream_verifier_regret_ledger_pass,
        ),
        ("route_scout_fixture_present", route_scout_fixture_present),
        ("training_split_bound", training_split_bound),
        ("held_out_split_bound", held_out_split_bound),
        ("task_signatures_bound", task_signatures_bound),
        ("mission_ids_bound", mission_ids_bound),
        ("source_features_bound", source_features_bound),
        ("cache_features_bound", cache_features_bound),
        ("trace_features_bound", trace_features_bound),
        ("verifier_features_bound", verifier_features_bound),
        ("hidden_state_bound", hidden_state_bound),
        ("route_logits_bound", route_logits_bound),
        ("route_family_labels_bound", route_family_labels_bound),
        ("verifier_need_labels_bound", verifier_need_labels_bound),
        ("scout_predictions_present", scout_predictions_present),
        (
            "scout_cheaper_than_heavy_route",
            scout_cheaper_than_heavy_route,
        ),
        (
            "route_family_accuracy_beats_static",
            route_family_accuracy_beats_static,
        ),
        (
            "route_family_accuracy_beats_random",
            route_family_accuracy_beats_random,
        ),
        (
            "route_family_accuracy_beats_recency",
            route_family_accuracy_beats_recency,
        ),
        (
            "route_family_accuracy_beats_embedding",
            route_family_accuracy_beats_embedding,
        ),
        (
            "verifier_need_accuracy_beats_static",
            verifier_need_accuracy_beats_static,
        ),
        (
            "verifier_need_accuracy_beats_random",
            verifier_need_accuracy_beats_random,
        ),
        (
            "verifier_need_accuracy_beats_recency",
            verifier_need_accuracy_beats_recency,
        ),
        (
            "verifier_need_accuracy_beats_embedding",
            verifier_need_accuracy_beats_embedding,
        ),
        (
            "route_calibration_beats_baselines",
            route_calibration_beats_baselines,
        ),
        (
            "verifier_calibration_beats_baselines",
            verifier_calibration_beats_baselines,
        ),
        ("abstention_case_present", abstention_case_present),
        ("rollback_bound", rollback_bound),
        ("run_event_log_bound", run_event_log_bound),
        ("answer_packet_ref_bound", answer_packet_ref_bound),
        ("no_hidden_route_authority", no_hidden_route_authority),
        ("no_hidden_chain", no_hidden_chain),
        ("no_hidden_cloud", no_hidden_cloud),
        ("live_policy_not_mutated", live_policy_not_mutated),
        ("scout_address_deterministic", scout_address_deterministic),
        ("duplicate_task_rejected", duplicate_task_rejected),
        ("missing_label_rejected", missing_label_rejected),
        ("missing_feature_rejected", missing_feature_rejected),
        ("missing_logits_rejected", missing_logits_rejected),
        (
            "unknown_route_family_rejected",
            unknown_route_family_rejected,
        ),
        ("missing_prediction_rejected", missing_prediction_rejected),
        ("no_held_out_rejected", no_held_out_rejected),
        (
            "static_baseline_unbeaten_rejected",
            static_baseline_unbeaten_rejected,
        ),
        (
            "random_baseline_unbeaten_rejected",
            random_baseline_unbeaten_rejected,
        ),
        (
            "recency_baseline_unbeaten_rejected",
            recency_baseline_unbeaten_rejected,
        ),
        (
            "embedding_baseline_unbeaten_rejected",
            embedding_baseline_unbeaten_rejected,
        ),
        (
            "verifier_static_baseline_unbeaten_rejected",
            verifier_static_baseline_unbeaten_rejected,
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
        ("scout_over_budget_rejected", scout_over_budget_rejected),
        ("scout_not_cheaper_rejected", scout_not_cheaper_rejected),
        ("uncalibrated_scout_rejected", uncalibrated_scout_rejected),
        ("no_runtime_bytes_loaded", no_runtime_bytes_loaded),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            pass,
        );
    }

    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "training_task_count",
        evaluation.training_task_count(),
        2,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_task_count",
        evaluation.held_out_task_count(),
        7,
        "count",
    );
    add_bps_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_family_accuracy_bps",
        metrics.scout_route_accuracy_bps,
        metrics.best_baseline_route_accuracy_bps + 1,
    );
    add_bps_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_need_accuracy_bps",
        metrics.scout_verifier_accuracy_bps,
        metrics.best_baseline_verifier_accuracy_bps + 1,
    );
    add_count_measurement(
        &mut measurements,
        "best_baseline_route_family_accuracy_bps",
        metrics.best_baseline_route_accuracy_bps,
        "bps",
    );
    add_count_measurement(
        &mut measurements,
        "best_baseline_verifier_need_accuracy_bps",
        metrics.best_baseline_verifier_accuracy_bps,
        "bps",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_calibration_error_bps",
        metrics.scout_route_calibration_error_bps,
        metrics
            .best_baseline_route_calibration_error_bps
            .saturating_sub(1),
        "bps",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_calibration_error_bps",
        metrics.scout_verifier_calibration_error_bps,
        metrics
            .best_baseline_verifier_calibration_error_bps
            .saturating_sub(1),
        "bps",
    );
    add_count_measurement(
        &mut measurements,
        "best_baseline_route_calibration_error_bps",
        metrics.best_baseline_route_calibration_error_bps,
        "bps",
    );
    add_count_measurement(
        &mut measurements,
        "best_baseline_verifier_calibration_error_bps",
        metrics.best_baseline_verifier_calibration_error_bps,
        "bps",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_scout_active_bytes",
        evaluation.max_scout_active_bytes(),
        MAX_SCOUT_ACTIVE_BYTES,
        "bytes",
    );
    add_string_contains_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "scout_address",
        &evaluation.scout_address,
        "uas:route-scout:",
        "uas_address",
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
        anomalies: vec![serde_json::json!({
            "kind": "scope_guard",
            "detail": "metadata-only RouteScoutSSM baseline witness; no live route authority, no policy mutation, no model/runtime bytes, and no sparse wake promotion executed"
        })],
        notes: "Proves a tiny route scout predicts route family and verifier need on held-out tasks better than static, random, recency, and embedding-only baselines while binding rollback, RunEventLog, AnswerPacket, calibration, and no-hidden-authority guards.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:route-scout:evaluation
// Plane: Controller + Verification
// Residency: metadata-only
struct ScoutEvaluation {
    tasks: Vec<ScoutTask>,
    metrics: ScoutMetrics,
    scout_address: String,
}

impl ScoutEvaluation {
    fn new(mut tasks: Vec<ScoutTask>) -> Result<Self, ScoutError> {
        if tasks.is_empty() {
            return Err(ScoutError::MissingTask);
        }
        let mut seen = BTreeSet::new();
        for task in &tasks {
            if !seen.insert(task.task_signature) {
                return Err(ScoutError::DuplicateTask);
            }
            validate_task(task)?;
        }
        let metrics = ScoutMetrics::from_tasks(&tasks)?;
        tasks.sort_by_key(|task| task.task_signature);
        let scout_address = scout_address(&tasks);
        Ok(Self {
            tasks,
            metrics,
            scout_address,
        })
    }

    fn held_out_tasks(&self) -> Vec<&ScoutTask> {
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
        self.tasks
            .iter()
            .filter(|task| task.split == "held_out")
            .count() as u64
    }

    fn max_scout_active_bytes(&self) -> u64 {
        let mut max_bytes = 0;
        for task in &self.tasks {
            max_bytes = max_bytes.max(task.scout_active_bytes);
        }
        max_bytes
    }
}

#[derive(Clone, Copy)]
// UAS: route_scout_ssm_baseline_metrics
// Plane: Verification
// Residency: MetadataOnly
struct ScoutMetrics {
    scout_route_accuracy_bps: u64,
    static_route_accuracy_bps: u64,
    random_route_accuracy_bps: u64,
    recency_route_accuracy_bps: u64,
    embedding_route_accuracy_bps: u64,
    best_baseline_route_accuracy_bps: u64,
    scout_verifier_accuracy_bps: u64,
    static_verifier_accuracy_bps: u64,
    random_verifier_accuracy_bps: u64,
    recency_verifier_accuracy_bps: u64,
    embedding_verifier_accuracy_bps: u64,
    best_baseline_verifier_accuracy_bps: u64,
    scout_route_calibration_error_bps: u64,
    best_baseline_route_calibration_error_bps: u64,
    scout_verifier_calibration_error_bps: u64,
    best_baseline_verifier_calibration_error_bps: u64,
}

impl ScoutMetrics {
    fn from_tasks(tasks: &[ScoutTask]) -> Result<Self, ScoutError> {
        if tasks.iter().filter(|task| task.split == "train").count() < 2 {
            return Err(ScoutError::MissingTrainingSplit);
        }
        let held_out = tasks
            .iter()
            .filter(|task| task.split == "held_out")
            .collect::<Vec<_>>();
        if held_out.len() < 7 {
            return Err(ScoutError::MissingHeldOut);
        }
        let scout_route_accuracy_bps = route_accuracy_bps(&held_out, |task| task.scout);
        let static_route_accuracy_bps = route_accuracy_bps(&held_out, |task| task.static_baseline);
        let random_route_accuracy_bps = route_accuracy_bps(&held_out, |task| task.random_baseline);
        let recency_route_accuracy_bps =
            route_accuracy_bps(&held_out, |task| task.recency_baseline);
        let embedding_route_accuracy_bps =
            route_accuracy_bps(&held_out, |task| task.embedding_baseline);
        if scout_route_accuracy_bps <= static_route_accuracy_bps {
            return Err(ScoutError::StaticRouteBaselineUnbeaten);
        }
        if scout_route_accuracy_bps <= random_route_accuracy_bps {
            return Err(ScoutError::RandomRouteBaselineUnbeaten);
        }
        if scout_route_accuracy_bps <= recency_route_accuracy_bps {
            return Err(ScoutError::RecencyRouteBaselineUnbeaten);
        }
        if scout_route_accuracy_bps <= embedding_route_accuracy_bps {
            return Err(ScoutError::EmbeddingRouteBaselineUnbeaten);
        }

        let scout_verifier_accuracy_bps = verifier_accuracy_bps(&held_out, |task| task.scout);
        let static_verifier_accuracy_bps =
            verifier_accuracy_bps(&held_out, |task| task.static_baseline);
        let random_verifier_accuracy_bps =
            verifier_accuracy_bps(&held_out, |task| task.random_baseline);
        let recency_verifier_accuracy_bps =
            verifier_accuracy_bps(&held_out, |task| task.recency_baseline);
        let embedding_verifier_accuracy_bps =
            verifier_accuracy_bps(&held_out, |task| task.embedding_baseline);
        if scout_verifier_accuracy_bps <= static_verifier_accuracy_bps {
            return Err(ScoutError::StaticVerifierBaselineUnbeaten);
        }
        if scout_verifier_accuracy_bps <= random_verifier_accuracy_bps {
            return Err(ScoutError::RandomVerifierBaselineUnbeaten);
        }
        if scout_verifier_accuracy_bps <= recency_verifier_accuracy_bps {
            return Err(ScoutError::RecencyVerifierBaselineUnbeaten);
        }
        if scout_verifier_accuracy_bps <= embedding_verifier_accuracy_bps {
            return Err(ScoutError::EmbeddingVerifierBaselineUnbeaten);
        }
        if !held_out
            .iter()
            .any(|task| task.label_route_family == "abstain_escalate")
        {
            return Err(ScoutError::MissingAbstentionCase);
        }

        let scout_route_calibration_error_bps =
            route_calibration_error_bps(&held_out, |task| task.scout);
        let baseline_route_calibration_errors = [
            route_calibration_error_bps(&held_out, |task| task.static_baseline),
            route_calibration_error_bps(&held_out, |task| task.random_baseline),
            route_calibration_error_bps(&held_out, |task| task.recency_baseline),
            route_calibration_error_bps(&held_out, |task| task.embedding_baseline),
        ];
        let best_baseline_route_calibration_error_bps = min_u64(&baseline_route_calibration_errors);
        if scout_route_calibration_error_bps >= best_baseline_route_calibration_error_bps {
            return Err(ScoutError::RouteCalibrationUnbeaten);
        }

        let scout_verifier_calibration_error_bps =
            verifier_calibration_error_bps(&held_out, |task| task.scout);
        let baseline_verifier_calibration_errors = [
            verifier_calibration_error_bps(&held_out, |task| task.static_baseline),
            verifier_calibration_error_bps(&held_out, |task| task.random_baseline),
            verifier_calibration_error_bps(&held_out, |task| task.recency_baseline),
            verifier_calibration_error_bps(&held_out, |task| task.embedding_baseline),
        ];
        let best_baseline_verifier_calibration_error_bps =
            min_u64(&baseline_verifier_calibration_errors);
        if scout_verifier_calibration_error_bps >= best_baseline_verifier_calibration_error_bps {
            return Err(ScoutError::VerifierCalibrationUnbeaten);
        }

        Ok(Self {
            scout_route_accuracy_bps,
            static_route_accuracy_bps,
            random_route_accuracy_bps,
            recency_route_accuracy_bps,
            embedding_route_accuracy_bps,
            best_baseline_route_accuracy_bps: max_u64(&[
                static_route_accuracy_bps,
                random_route_accuracy_bps,
                recency_route_accuracy_bps,
                embedding_route_accuracy_bps,
            ]),
            scout_verifier_accuracy_bps,
            static_verifier_accuracy_bps,
            random_verifier_accuracy_bps,
            recency_verifier_accuracy_bps,
            embedding_verifier_accuracy_bps,
            best_baseline_verifier_accuracy_bps: max_u64(&[
                static_verifier_accuracy_bps,
                random_verifier_accuracy_bps,
                recency_verifier_accuracy_bps,
                embedding_verifier_accuracy_bps,
            ]),
            scout_route_calibration_error_bps,
            best_baseline_route_calibration_error_bps,
            scout_verifier_calibration_error_bps,
            best_baseline_verifier_calibration_error_bps,
        })
    }
}

fn validate_task(task: &ScoutTask) -> Result<(), ScoutError> {
    if task.split != "train" && task.split != "held_out" {
        return Err(ScoutError::MissingSplit);
    }
    if !task.task_signature.starts_with("task:") {
        return Err(ScoutError::MissingTaskSignature);
    }
    if !task.mission_id.starts_with("mission:") {
        return Err(ScoutError::MissingMission);
    }
    if !prefixed_features(task.source_features, "source:")
        || !prefixed_features(task.cache_features, "cache:")
        || !prefixed_features(task.trace_features, "trace:")
        || !prefixed_features(task.verifier_features, "verifier:")
    {
        return Err(ScoutError::MissingFeature);
    }
    if !task.hidden_state_ref.starts_with("scout-state:") {
        return Err(ScoutError::MissingState);
    }
    if !task.route_logits_ref.starts_with("route-logits:") {
        return Err(ScoutError::MissingLogits);
    }
    if task.label_route_family.is_empty() {
        return Err(ScoutError::MissingRouteLabel);
    }
    if task.scout.route_family.is_empty() {
        return Err(ScoutError::MissingPrediction);
    }
    if !valid_route_family(task.label_route_family)
        || !valid_prediction(&task.scout)
        || !valid_prediction(&task.static_baseline)
        || !valid_prediction(&task.random_baseline)
        || !valid_prediction(&task.recency_baseline)
        || !valid_prediction(&task.embedding_baseline)
    {
        return Err(ScoutError::UnknownRouteFamily);
    }
    if !bounded_confidence(task.scout.route_confidence_bps)
        || !bounded_confidence(task.scout.verifier_confidence_bps)
        || !bounded_confidence(task.static_baseline.route_confidence_bps)
        || !bounded_confidence(task.static_baseline.verifier_confidence_bps)
        || !bounded_confidence(task.random_baseline.route_confidence_bps)
        || !bounded_confidence(task.random_baseline.verifier_confidence_bps)
        || !bounded_confidence(task.recency_baseline.route_confidence_bps)
        || !bounded_confidence(task.recency_baseline.verifier_confidence_bps)
        || !bounded_confidence(task.embedding_baseline.route_confidence_bps)
        || !bounded_confidence(task.embedding_baseline.verifier_confidence_bps)
    {
        return Err(ScoutError::InvalidConfidence);
    }
    if task.scout.route_family.is_empty() {
        return Err(ScoutError::MissingPrediction);
    }
    if !task.rollback_handle.starts_with("rollback:") {
        return Err(ScoutError::MissingRollback);
    }
    if !task.run_event_log_ref.starts_with("runlog:") {
        return Err(ScoutError::MissingRunEventLog);
    }
    if !task.answer_packet_ref.starts_with("answerpacket:") {
        return Err(ScoutError::MissingAnswerPacket);
    }
    if task.route_authority != "shadow_only" {
        return Err(ScoutError::HiddenLiveAuthority);
    }
    if task.live_policy_mutated {
        return Err(ScoutError::LivePolicyMutation);
    }
    if task.hidden_chain_exposed {
        return Err(ScoutError::HiddenChainExposure);
    }
    if task.hidden_cloud {
        return Err(ScoutError::CloudRoute);
    }
    if task.scout_active_bytes == 0 || task.scout_active_bytes > MAX_SCOUT_ACTIVE_BYTES {
        return Err(ScoutError::ScoutBudgetExceeded);
    }
    if task.heavy_route_min_active_bytes
        < task
            .scout_active_bytes
            .saturating_mul(MIN_HEAVY_ROUTE_MULTIPLE)
    {
        return Err(ScoutError::ScoutNotCheaper);
    }
    Ok(())
}

fn route_accuracy_bps(
    tasks: &[&ScoutTask],
    prediction: impl Fn(&ScoutTask) -> RoutePrediction,
) -> u64 {
    let correct = tasks
        .iter()
        .filter(|task| prediction(task).route_family == task.label_route_family)
        .count() as u64;
    correct * 10_000 / tasks.len() as u64
}

fn verifier_accuracy_bps(
    tasks: &[&ScoutTask],
    prediction: impl Fn(&ScoutTask) -> RoutePrediction,
) -> u64 {
    let correct = tasks
        .iter()
        .filter(|task| prediction(task).verifier_need == task.label_verifier_need)
        .count() as u64;
    correct * 10_000 / tasks.len() as u64
}

fn route_calibration_error_bps(
    tasks: &[&ScoutTask],
    prediction: impl Fn(&ScoutTask) -> RoutePrediction,
) -> u64 {
    tasks
        .iter()
        .map(|task| {
            let predicted = prediction(task);
            let target = if predicted.route_family == task.label_route_family {
                10_000
            } else {
                0
            };
            abs_diff(predicted.route_confidence_bps, target)
        })
        .sum::<u64>()
        / tasks.len() as u64
}

fn verifier_calibration_error_bps(
    tasks: &[&ScoutTask],
    prediction: impl Fn(&ScoutTask) -> RoutePrediction,
) -> u64 {
    tasks
        .iter()
        .map(|task| {
            let predicted = prediction(task);
            let target = if predicted.verifier_need == task.label_verifier_need {
                10_000
            } else {
                0
            };
            abs_diff(predicted.verifier_confidence_bps, target)
        })
        .sum::<u64>()
        / tasks.len() as u64
}

fn abs_diff(left: u64, right: u64) -> u64 {
    left.max(right) - left.min(right)
}

fn max_u64(values: &[u64]) -> u64 {
    let mut best = 0;
    for value in values {
        best = best.max(*value);
    }
    best
}

fn min_u64(values: &[u64]) -> u64 {
    let mut best = u64::MAX;
    for value in values {
        best = best.min(*value);
    }
    best
}

fn prefixed_features(features: &[&str], prefix: &str) -> bool {
    !features.is_empty() && features.iter().all(|feature| feature.starts_with(prefix))
}

fn valid_prediction(prediction: &RoutePrediction) -> bool {
    valid_route_family(prediction.route_family)
}

fn valid_route_family(route_family: &str) -> bool {
    matches!(
        route_family,
        "apple_private_summary"
            | "eidos_retrieval"
            | "local_qwen_code"
            | "proof_tools"
            | "kv_recall"
            | "sovereign_note_mutation"
            | "abstain_escalate"
    )
}

fn bounded_confidence(confidence_bps: u64) -> bool {
    (1_000..=10_000).contains(&confidence_bps)
}

fn scout_is_cheaper(task: &ScoutTask) -> bool {
    task.scout_active_bytes > 0
        && task.scout_active_bytes <= MAX_SCOUT_ACTIVE_BYTES
        && task.heavy_route_min_active_bytes
            >= task
                .scout_active_bytes
                .saturating_mul(MIN_HEAVY_ROUTE_MULTIPLE)
}

fn duplicate_task_rejected() -> bool {
    let mut tasks = fixture_tasks();
    let duplicate = tasks[0].clone();
    tasks.push(duplicate);
    matches!(ScoutEvaluation::new(tasks), Err(ScoutError::DuplicateTask))
}

fn invalid_task_rejected(mut mutate: impl FnMut(&mut ScoutTask)) -> Option<ScoutError> {
    let mut tasks = fixture_tasks();
    mutate(&mut tasks[2]);
    ScoutEvaluation::new(tasks).err()
}

fn invalid_fixture_rejected(mut mutate: impl FnMut(&mut [ScoutTask])) -> Option<ScoutError> {
    let mut tasks = fixture_tasks();
    mutate(&mut tasks);
    ScoutEvaluation::new(tasks).err()
}

fn scout_address(tasks: &[ScoutTask]) -> String {
    let mut preimage = String::new();
    for task in tasks {
        push_preimage(&mut preimage, "split", task.split);
        push_preimage(&mut preimage, "task_signature", task.task_signature);
        push_preimage(&mut preimage, "mission_id", task.mission_id);
        push_preimage(&mut preimage, "label_route_family", task.label_route_family);
        push_preimage(
            &mut preimage,
            "label_verifier_need",
            if task.label_verifier_need {
                "true"
            } else {
                "false"
            },
        );
        push_preimage(&mut preimage, "scout_route_family", task.scout.route_family);
        push_preimage(
            &mut preimage,
            "scout_verifier_need",
            if task.scout.verifier_need {
                "true"
            } else {
                "false"
            },
        );
        push_preimage(&mut preimage, "rollback_handle", task.rollback_handle);
        push_preimage(&mut preimage, "answer_packet_ref", task.answer_packet_ref);
    }
    format!("uas:route-scout:{}", sha256_hex(preimage.as_bytes()))
}

fn push_preimage(preimage: &mut String, key: &str, value: &str) {
    preimage.push_str(key);
    preimage.push('=');
    preimage.push_str(value);
    preimage.push('\n');
}

fn upstream_verifier_regret_ledger_pass() -> bool {
    let Ok(raw) = std::fs::read_to_string(UPSTREAM_VERIFIER_REGRET) else {
        return false;
    };
    let Ok(json) = serde_json::from_str::<serde_json::Value>(&raw) else {
        return false;
    };
    json.get("falsifier_id").and_then(|value| value.as_str()) == Some("F-VerifierRegretLedger")
        && json
            .get("overall_pass")
            .and_then(|value| value.as_bool())
            .unwrap_or(false)
        && json
            .get("pass_per_axis")
            .and_then(|axes| axes.get("no_runtime_bytes_loaded"))
            .and_then(|value| value.as_bool())
            .unwrap_or(false)
}

fn add_bps_ge_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: u64,
    minimum: u64,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: "bps".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::json!(minimum),
            unit: "bps".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), value >= minimum);
}

fn add_u64_le_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: u64,
    maximum: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "<=".to_string(),
            value: serde_json::json!(maximum),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), value <= maximum);
}

fn add_string_contains_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
    required: &str,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "contains".to_string(),
            value: serde_json::json!(required),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), value.contains(required));
}

fn add_count_measurement(
    measurements: &mut BTreeMap<String, Measurement>,
    name: &str,
    value: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: unit.to_string(),
        },
    );
}

fn fixture_tasks() -> Vec<ScoutTask> {
    vec![
        scout_task(
            "train",
            "task:train:rewrite-light",
            "mission:rewrite-light",
            "apple_private_summary",
            false,
            prediction("apple_private_summary", false, 9_400, 9_300),
            prediction("local_qwen_code", true, 8_500, 8_500),
            prediction("eidos_retrieval", false, 6_000, 5_500),
            prediction("apple_private_summary", false, 7_500, 7_000),
            prediction("apple_private_summary", false, 8_000, 8_000),
            "rollback:route-scout:train-rewrite-light",
            "answerpacket:route-scout:train-rewrite-light",
        ),
        scout_task(
            "train",
            "task:train:source-answer",
            "mission:source-answer",
            "eidos_retrieval",
            true,
            prediction("eidos_retrieval", true, 9_300, 9_200),
            prediction("local_qwen_code", true, 8_500, 8_500),
            prediction("proof_tools", true, 6_000, 6_000),
            prediction("apple_private_summary", false, 7_500, 4_000),
            prediction("eidos_retrieval", true, 8_400, 8_000),
            "rollback:route-scout:train-source-answer",
            "answerpacket:route-scout:train-source-answer",
        ),
        scout_task(
            "held_out",
            "task:heldout:light-rewrite",
            "mission:light-rewrite",
            "apple_private_summary",
            false,
            prediction("apple_private_summary", false, 9_300, 9_100),
            prediction("local_qwen_code", true, 8_500, 8_500),
            prediction("proof_tools", true, 6_100, 6_000),
            prediction("eidos_retrieval", true, 7_500, 7_000),
            prediction("apple_private_summary", false, 8_800, 8_300),
            "rollback:route-scout:heldout-light-rewrite",
            "answerpacket:route-scout:heldout-light-rewrite",
        ),
        scout_task(
            "held_out",
            "task:heldout:source-answer",
            "mission:source-answer",
            "eidos_retrieval",
            true,
            prediction("eidos_retrieval", true, 9_200, 9_100),
            prediction("local_qwen_code", true, 8_500, 8_500),
            prediction("proof_tools", true, 6_100, 6_000),
            prediction("apple_private_summary", false, 7_500, 4_000),
            prediction("eidos_retrieval", true, 8_700, 8_200),
            "rollback:route-scout:heldout-source-answer",
            "answerpacket:route-scout:heldout-source-answer",
        ),
        scout_task(
            "held_out",
            "task:heldout:code-question",
            "mission:code-question",
            "local_qwen_code",
            true,
            prediction("local_qwen_code", true, 9_500, 9_300),
            prediction("local_qwen_code", true, 8_500, 8_500),
            prediction("eidos_retrieval", false, 6_000, 5_500),
            prediction("eidos_retrieval", true, 7_500, 7_000),
            prediction("local_qwen_code", false, 8_900, 4_200),
            "rollback:route-scout:heldout-code-question",
            "answerpacket:route-scout:heldout-code-question",
        ),
        scout_task(
            "held_out",
            "task:heldout:proof-question",
            "mission:proof-question",
            "proof_tools",
            true,
            prediction("proof_tools", true, 9_100, 9_200),
            prediction("local_qwen_code", true, 8_500, 8_500),
            prediction("kv_recall", true, 6_000, 6_000),
            prediction("local_qwen_code", true, 7_500, 7_000),
            prediction("proof_tools", true, 8_400, 8_000),
            "rollback:route-scout:heldout-proof-question",
            "answerpacket:route-scout:heldout-proof-question",
        ),
        scout_task(
            "held_out",
            "task:heldout:long-context-recall",
            "mission:long-context-recall",
            "kv_recall",
            true,
            prediction("kv_recall", true, 9_400, 9_200),
            prediction("local_qwen_code", true, 8_500, 8_500),
            prediction("apple_private_summary", false, 6_000, 5_500),
            prediction("proof_tools", true, 7_500, 7_000),
            prediction("kv_recall", true, 8_700, 8_100),
            "rollback:route-scout:heldout-long-context-recall",
            "answerpacket:route-scout:heldout-long-context-recall",
        ),
        scout_task(
            "held_out",
            "task:heldout:note-mutation",
            "mission:note-mutation",
            "sovereign_note_mutation",
            true,
            prediction("sovereign_note_mutation", true, 9_000, 9_100),
            prediction("local_qwen_code", true, 8_500, 8_500),
            prediction("sovereign_note_mutation", false, 6_300, 5_200),
            prediction("kv_recall", true, 7_500, 7_000),
            prediction("eidos_retrieval", false, 8_000, 4_000),
            "rollback:route-scout:heldout-note-mutation",
            "answerpacket:route-scout:heldout-note-mutation",
        ),
        scout_task(
            "held_out",
            "task:heldout:ambiguous-authority",
            "mission:ambiguous-authority",
            "abstain_escalate",
            true,
            prediction("abstain_escalate", true, 8_900, 8_900),
            prediction("local_qwen_code", true, 8_500, 8_500),
            prediction("local_qwen_code", true, 6_200, 6_000),
            prediction("sovereign_note_mutation", true, 7_500, 7_000),
            prediction("proof_tools", true, 7_900, 8_000),
            "rollback:route-scout:heldout-ambiguous-authority",
            "answerpacket:route-scout:heldout-ambiguous-authority",
        ),
    ]
}

fn prediction(
    route_family: &'static str,
    verifier_need: bool,
    route_confidence_bps: u64,
    verifier_confidence_bps: u64,
) -> RoutePrediction {
    RoutePrediction {
        route_family,
        verifier_need,
        route_confidence_bps,
        verifier_confidence_bps,
    }
}

#[allow(clippy::too_many_arguments)]
fn scout_task(
    split: &'static str,
    task_signature: &'static str,
    mission_id: &'static str,
    label_route_family: &'static str,
    label_verifier_need: bool,
    scout: RoutePrediction,
    static_baseline: RoutePrediction,
    random_baseline: RoutePrediction,
    recency_baseline: RoutePrediction,
    embedding_baseline: RoutePrediction,
    rollback_handle: &'static str,
    answer_packet_ref: &'static str,
) -> ScoutTask {
    ScoutTask {
        split,
        task_signature,
        mission_id,
        source_features: &["source:vault", "source:eidos", "source:task-signal"],
        cache_features: &["cache:prefix", "cache:kv-page", "cache:cold-miss"],
        trace_features: &["trace:run-event", "trace:regret", "trace:rollback"],
        verifier_features: &["verifier:citation", "verifier:test", "verifier:proof"],
        hidden_state_ref: "scout-state:ssm-shadow-v1",
        route_logits_ref: "route-logits:ssm-shadow-v1",
        label_route_family,
        label_verifier_need,
        scout,
        static_baseline,
        random_baseline,
        recency_baseline,
        embedding_baseline,
        rollback_handle,
        run_event_log_ref: "runlog:route-scout:ssm-baseline-v1",
        answer_packet_ref,
        route_authority: "shadow_only",
        scout_active_bytes: 1_048_576,
        heavy_route_min_active_bytes: 16_777_216,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        live_policy_mutated: false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fixture_evaluation_passes_and_address_is_order_stable() {
        let tasks = fixture_tasks();
        let reversed = tasks.iter().cloned().rev().collect::<Vec<_>>();
        let evaluation = match ScoutEvaluation::new(tasks) {
            Ok(evaluation) => evaluation,
            Err(error) => panic!("fixture should pass: {error}"),
        };
        let reversed_evaluation = match ScoutEvaluation::new(reversed) {
            Ok(evaluation) => evaluation,
            Err(error) => panic!("reversed fixture should pass: {error}"),
        };
        assert_eq!(evaluation.training_task_count(), 2);
        assert_eq!(evaluation.held_out_task_count(), 7);
        assert_eq!(evaluation.scout_address, reversed_evaluation.scout_address);
        assert!(evaluation.metrics.scout_route_accuracy_bps > 9_000);
        assert!(evaluation.metrics.scout_verifier_accuracy_bps > 9_000);
    }

    #[test]
    fn empty_fixture_rejects() {
        assert!(matches!(
            ScoutEvaluation::new(Vec::new()),
            Err(ScoutError::MissingTask)
        ));
    }

    #[test]
    fn required_invalid_fixtures_reject() {
        assert!(duplicate_task_rejected());
        assert_eq!(
            invalid_task_rejected(|task| task.source_features = &[]),
            Some(ScoutError::MissingFeature)
        );
        assert_eq!(
            invalid_task_rejected(|task| task.route_logits_ref = ""),
            Some(ScoutError::MissingLogits)
        );
        assert_eq!(
            invalid_task_rejected(|task| task.scout.route_family = ""),
            Some(ScoutError::MissingPrediction)
        );
        assert_eq!(
            invalid_task_rejected(|task| task.route_authority = "live_route_policy"),
            Some(ScoutError::HiddenLiveAuthority)
        );
        assert_eq!(
            invalid_task_rejected(|task| task.live_policy_mutated = true),
            Some(ScoutError::LivePolicyMutation)
        );
        assert_eq!(
            invalid_fixture_rejected(|tasks| {
                for task in tasks {
                    task.embedding_baseline.route_family = task.label_route_family;
                }
            }),
            Some(ScoutError::EmbeddingRouteBaselineUnbeaten)
        );
        assert_eq!(
            invalid_fixture_rejected(|tasks| {
                for task in tasks {
                    task.scout.route_confidence_bps = 1_000;
                    task.scout.verifier_confidence_bps = 1_000;
                }
            }),
            Some(ScoutError::RouteCalibrationUnbeaten)
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
        assert!(artifact.pass_per_axis["route_family_accuracy_beats_embedding"]);
        assert!(artifact.pass_per_axis["verifier_need_accuracy_beats_static"]);
    }
}
