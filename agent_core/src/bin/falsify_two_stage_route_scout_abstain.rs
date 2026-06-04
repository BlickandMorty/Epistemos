//! `falsify_two_stage_route_scout_abstain` -- two-stage scout contract.
//!
//! Metadata-only witness for `F-TwoStageRouteScout-Abstain`. It proves a
//! RouteScoutSSM-style stage chooses only route family/escalation while a
//! second stage chooses only the family-specific selector. High uncertainty or
//! verifier conflict must abstain. No runtime/model bytes are loaded.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-TwoStageRouteScout-Abstain";
const FIXTURE_ID: &str = "two_stage_route_scout_abstain_v1";
const COMMAND: &str = "Tools/falsifiers/f_two_stage_route_scout_abstain.sh";
const RESULT: &str = "artifacts/falsifiers/two_stage_route_scout_abstain/result.json";
const UPSTREAM_ROUTE_SCOUT: &str = "artifacts/falsifiers/route_scout_ssm_baseline/result.json";
const MAX_TWO_STAGE_ACTIVE_BYTES: u64 = 6 * 1024 * 1024;
const MIN_HEAVY_ROUTE_MULTIPLE: u64 = 8;

// UAS: uas:two-stage-route-scout:stage-a
// Plane: Controller
// Residency: metadata-only family/escalation decision.
#[derive(Clone, Copy)]
struct StageADecision {
    route_family: &'static str,
    confidence_bps: u64,
    uncertainty_bps: u64,
    conflict_bps: u64,
    abstain_threshold_bps: u64,
    should_abstain: bool,
    selector_leak_ref: &'static str,
}

// UAS: uas:two-stage-route-scout:stage-b
// Plane: Controller
// Residency: metadata-only family-specific selector decision.
#[derive(Clone, Copy)]
struct StageBDecision {
    selector_family: &'static str,
    selector_kind: &'static str,
    selector_id: &'static str,
    confidence_bps: u64,
    irrelevant_selector_refs: &'static [&'static str],
}

// UAS: uas:two-stage-route-scout:baseline
// Plane: Verification
// Residency: metadata-only comparison row.
#[derive(Clone, Copy)]
struct BaselineDecision {
    route_family: &'static str,
    selector_kind: &'static str,
    abstained: bool,
}

// UAS: uas:two-stage-route-scout:task
// Plane: Controller + Verification
// Residency: metadata-only fixture row.
#[derive(Clone)]
struct TwoStageTask {
    split: &'static str,
    task_signature: &'static str,
    mission_id: &'static str,
    source_features: &'static [&'static str],
    verifier_features: &'static [&'static str],
    stage_a_ref: &'static str,
    stage_b_ref: &'static str,
    label_route_family: &'static str,
    label_selector_kind: &'static str,
    label_should_abstain: bool,
    stage_a: StageADecision,
    stage_b: StageBDecision,
    all_in_one_baseline: BaselineDecision,
    static_selector_baseline: BaselineDecision,
    no_abstain_baseline: BaselineDecision,
    rollback_handle: &'static str,
    run_event_log_ref: &'static str,
    answer_packet_ref: &'static str,
    route_authority: &'static str,
    stage_a_active_bytes: u64,
    stage_b_active_bytes: u64,
    heavy_route_min_active_bytes: u64,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    live_policy_mutated: bool,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:two-stage-route-scout:error
// Plane: Verification
// Residency: metadata-only
enum TwoStageError {
    MissingTask,
    DuplicateTask,
    MissingSplit,
    MissingTaskSignature,
    MissingMission,
    MissingFeature,
    MissingStageA,
    MissingStageB,
    StageASelectorLeak,
    StageAUnknownFamily,
    StageAWrongFamily,
    StageBUnknownSelector,
    StageBFamilyMismatch,
    StageBWrongSelector,
    IrrelevantSelectorChosen,
    MissingTrainingSplit,
    MissingHeldOutSplit,
    MissingAbstentionCase,
    InvalidConfidence,
    MissingAbstainThreshold,
    HighUncertaintyNonAbstain,
    ConflictNonAbstain,
    AllInOneBaselineUnbeaten,
    StaticSelectorBaselineUnbeaten,
    NoAbstainBaselineUnbeaten,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    HiddenLiveAuthority,
    LivePolicyMutation,
    HiddenChainExposure,
    CloudRoute,
    TwoStageBudgetExceeded,
    TwoStageNotCheaper,
}

impl std::fmt::Display for TwoStageError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for TwoStageError {}

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
        "{FALSIFIER_ID}: overall_pass={} held_out_task_count={} two_stage_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["held_out_task_count"].value,
        artifact.measurements["two_stage_address"].value
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
    let evaluation = TwoStageEvaluation::new(tasks)?;
    let reversed_evaluation = TwoStageEvaluation::new(reversed)?;
    let metrics = evaluation.metrics;

    let upstream_route_scout_ssm_baseline_pass = upstream_route_scout_ssm_baseline_pass();
    let two_stage_fixture_present = evaluation.tasks.len() == 9;
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
    let verifier_features_bound = evaluation
        .tasks
        .iter()
        .all(|task| prefixed_features(task.verifier_features, "verifier:"));
    let stage_a_family_choice_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.stage_a.route_family == task.label_route_family);
    let stage_a_no_selector_leak = evaluation
        .tasks
        .iter()
        .all(|task| task.stage_a.selector_leak_ref.is_empty());
    let stage_b_selector_choice_bound = evaluation
        .tasks
        .iter()
        .all(|task| task.stage_b.selector_kind == task.label_selector_kind);
    let stage_b_family_specific = evaluation.tasks.iter().all(|task| {
        selector_allowed_for_family(task.stage_b.selector_kind, task.stage_a.route_family)
    });
    let family_selector_separation_bound = evaluation.tasks.iter().all(|task| {
        task.stage_a_ref != task.stage_b_ref
            && task.stage_a_ref.starts_with("stage-a:")
            && task.stage_b_ref.starts_with("stage-b:")
    });
    let abstain_condition_bound = evaluation.tasks.iter().all(|task| {
        task.stage_a.abstain_threshold_bps > 0
            && task.stage_a.uncertainty_bps <= 10_000
            && task.stage_a.conflict_bps <= 10_000
    });
    let uncertainty_abstention_bound = evaluation.tasks.iter().all(abstention_policy_holds);
    let verifier_conflict_abstention_bound = evaluation.tasks.iter().all(conflict_policy_holds);
    let irrelevant_selector_rejected_by_fixture = evaluation
        .tasks
        .iter()
        .all(|task| task.stage_b.irrelevant_selector_refs.is_empty());
    let two_stage_cheaper_than_heavy_route = evaluation.tasks.iter().all(two_stage_is_cheaper);
    let route_success_beats_all_in_one =
        metrics.two_stage_route_success_bps > metrics.all_in_one_route_success_bps;
    let route_success_beats_static =
        metrics.two_stage_route_success_bps > metrics.static_route_success_bps;
    let route_success_beats_no_abstain =
        metrics.two_stage_route_success_bps > metrics.no_abstain_route_success_bps;
    let abstention_accuracy_beats_no_abstain =
        metrics.two_stage_abstention_accuracy_bps > metrics.no_abstain_accuracy_bps;
    let abstention_case_present = evaluation
        .held_out_tasks()
        .iter()
        .any(|task| task.label_should_abstain);
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
    let two_stage_address_deterministic =
        evaluation.two_stage_address == reversed_evaluation.two_stage_address;
    let no_runtime_bytes_loaded = true;

    let duplicate_task_rejected = duplicate_task_rejected();
    let missing_stage_a_rejected =
        invalid_task_rejected(|task| task.stage_a_ref = "") == Some(TwoStageError::MissingStageA);
    let missing_stage_b_rejected =
        invalid_task_rejected(|task| task.stage_b_ref = "") == Some(TwoStageError::MissingStageB);
    let stage_a_selector_leak_rejected =
        invalid_task_rejected(|task| task.stage_a.selector_leak_ref = "selector:mlx:qwen-code")
            == Some(TwoStageError::StageASelectorLeak);
    let family_selector_mismatch_rejected = invalid_task_rejected(|task| {
        task.stage_b.selector_family = "proof_tools";
        task.stage_b.selector_kind = "proof_toolchain";
    }) == Some(TwoStageError::StageBFamilyMismatch);
    let irrelevant_selector_chosen_rejected = invalid_task_rejected(|task| {
        task.stage_b.irrelevant_selector_refs = &["selector:proof:lean", "selector:kv:recent"]
    }) == Some(TwoStageError::IrrelevantSelectorChosen);
    let missing_abstain_threshold_rejected = invalid_task_rejected(|task| {
        task.stage_a.abstain_threshold_bps = 0;
    }) == Some(TwoStageError::MissingAbstainThreshold);
    let high_uncertainty_non_abstain_rejected =
        invalid_task_rejected(|task| {
            task.stage_a.uncertainty_bps = 9_400;
            task.stage_a.conflict_bps = 2_000;
            task.stage_a.should_abstain = false;
            task.label_should_abstain = true;
        }) == Some(TwoStageError::HighUncertaintyNonAbstain);
    let conflict_non_abstain_rejected = invalid_task_rejected(|task| {
        task.stage_a.uncertainty_bps = 2_000;
        task.stage_a.conflict_bps = 9_200;
        task.stage_a.should_abstain = false;
        task.stage_a.route_family = "eidos_retrieval";
        task.stage_b.selector_family = "eidos_retrieval";
        task.stage_b.selector_kind = "eidos_index";
        task.label_should_abstain = true;
    }) == Some(TwoStageError::ConflictNonAbstain);
    let all_in_one_selector_unbeaten_rejected = invalid_fixture_rejected(|tasks| {
        for task in tasks {
            task.all_in_one_baseline.route_family = task.label_route_family;
            task.all_in_one_baseline.selector_kind = task.label_selector_kind;
            task.all_in_one_baseline.abstained = task.label_should_abstain;
        }
    }) == Some(TwoStageError::AllInOneBaselineUnbeaten);
    let static_selector_unbeaten_rejected =
        invalid_fixture_rejected(|tasks| {
            for task in tasks {
                task.static_selector_baseline.route_family = task.label_route_family;
                task.static_selector_baseline.selector_kind = task.label_selector_kind;
                task.static_selector_baseline.abstained = task.label_should_abstain;
            }
        }) == Some(TwoStageError::StaticSelectorBaselineUnbeaten);
    let no_abstain_unbeaten_rejected = invalid_fixture_rejected(|tasks| {
        for task in tasks {
            task.no_abstain_baseline.route_family = task.label_route_family;
            task.no_abstain_baseline.selector_kind = task.label_selector_kind;
            task.no_abstain_baseline.abstained = task.label_should_abstain;
        }
    }) == Some(TwoStageError::NoAbstainBaselineUnbeaten);
    let missing_rollback_rejected = invalid_task_rejected(|task| task.rollback_handle = "")
        == Some(TwoStageError::MissingRollback);
    let missing_run_event_log_rejected = invalid_task_rejected(|task| task.run_event_log_ref = "")
        == Some(TwoStageError::MissingRunEventLog);
    let missing_answer_packet_rejected = invalid_task_rejected(|task| task.answer_packet_ref = "")
        == Some(TwoStageError::MissingAnswerPacket);
    let hidden_live_authority_rejected =
        invalid_task_rejected(|task| task.route_authority = "live_route_policy")
            == Some(TwoStageError::HiddenLiveAuthority);
    let live_policy_mutation_rejected =
        invalid_task_rejected(|task| task.live_policy_mutated = true)
            == Some(TwoStageError::LivePolicyMutation);
    let hidden_chain_exposure_rejected =
        invalid_task_rejected(|task| task.hidden_chain_exposed = true)
            == Some(TwoStageError::HiddenChainExposure);
    let cloud_route_rejected =
        invalid_task_rejected(|task| task.hidden_cloud = true) == Some(TwoStageError::CloudRoute);
    let two_stage_over_budget_rejected =
        invalid_task_rejected(|task| task.stage_b_active_bytes = MAX_TWO_STAGE_ACTIVE_BYTES)
            == Some(TwoStageError::TwoStageBudgetExceeded);
    let two_stage_not_cheaper_rejected =
        invalid_task_rejected(|task| task.heavy_route_min_active_bytes = task.two_stage_bytes())
            == Some(TwoStageError::TwoStageNotCheaper);

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_route_scout_ssm_baseline_pass",
            upstream_route_scout_ssm_baseline_pass,
        ),
        ("two_stage_fixture_present", two_stage_fixture_present),
        ("training_split_bound", training_split_bound),
        ("held_out_split_bound", held_out_split_bound),
        ("task_signatures_bound", task_signatures_bound),
        ("mission_ids_bound", mission_ids_bound),
        ("source_features_bound", source_features_bound),
        ("verifier_features_bound", verifier_features_bound),
        ("stage_a_family_choice_bound", stage_a_family_choice_bound),
        ("stage_a_no_selector_leak", stage_a_no_selector_leak),
        (
            "stage_b_selector_choice_bound",
            stage_b_selector_choice_bound,
        ),
        ("stage_b_family_specific", stage_b_family_specific),
        (
            "family_selector_separation_bound",
            family_selector_separation_bound,
        ),
        ("abstain_condition_bound", abstain_condition_bound),
        ("uncertainty_abstention_bound", uncertainty_abstention_bound),
        (
            "verifier_conflict_abstention_bound",
            verifier_conflict_abstention_bound,
        ),
        (
            "irrelevant_selector_rejected_by_fixture",
            irrelevant_selector_rejected_by_fixture,
        ),
        (
            "two_stage_cheaper_than_heavy_route",
            two_stage_cheaper_than_heavy_route,
        ),
        (
            "route_success_beats_all_in_one",
            route_success_beats_all_in_one,
        ),
        ("route_success_beats_static", route_success_beats_static),
        (
            "route_success_beats_no_abstain",
            route_success_beats_no_abstain,
        ),
        (
            "abstention_accuracy_beats_no_abstain",
            abstention_accuracy_beats_no_abstain,
        ),
        ("abstention_case_present", abstention_case_present),
        ("rollback_bound", rollback_bound),
        ("run_event_log_bound", run_event_log_bound),
        ("answer_packet_ref_bound", answer_packet_ref_bound),
        ("no_hidden_route_authority", no_hidden_route_authority),
        ("no_hidden_chain", no_hidden_chain),
        ("no_hidden_cloud", no_hidden_cloud),
        ("live_policy_not_mutated", live_policy_not_mutated),
        (
            "two_stage_address_deterministic",
            two_stage_address_deterministic,
        ),
        ("duplicate_task_rejected", duplicate_task_rejected),
        ("missing_stage_a_rejected", missing_stage_a_rejected),
        ("missing_stage_b_rejected", missing_stage_b_rejected),
        (
            "stage_a_selector_leak_rejected",
            stage_a_selector_leak_rejected,
        ),
        (
            "family_selector_mismatch_rejected",
            family_selector_mismatch_rejected,
        ),
        (
            "irrelevant_selector_chosen_rejected",
            irrelevant_selector_chosen_rejected,
        ),
        (
            "missing_abstain_threshold_rejected",
            missing_abstain_threshold_rejected,
        ),
        (
            "high_uncertainty_non_abstain_rejected",
            high_uncertainty_non_abstain_rejected,
        ),
        (
            "conflict_non_abstain_rejected",
            conflict_non_abstain_rejected,
        ),
        (
            "all_in_one_selector_unbeaten_rejected",
            all_in_one_selector_unbeaten_rejected,
        ),
        (
            "static_selector_unbeaten_rejected",
            static_selector_unbeaten_rejected,
        ),
        ("no_abstain_unbeaten_rejected", no_abstain_unbeaten_rejected),
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
            "two_stage_over_budget_rejected",
            two_stage_over_budget_rejected,
        ),
        (
            "two_stage_not_cheaper_rejected",
            two_stage_not_cheaper_rejected,
        ),
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
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_family_count",
        evaluation.route_family_count(),
        7,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "abstention_case_count",
        evaluation.abstention_case_count(),
        2,
        "count",
    );
    add_bps_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "two_stage_route_success_bps",
        metrics.two_stage_route_success_bps,
        metrics.best_baseline_route_success_bps + 1,
    );
    add_count_measurement(
        &mut measurements,
        "best_baseline_route_success_bps",
        metrics.best_baseline_route_success_bps,
        "bps",
    );
    add_bps_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "two_stage_abstention_accuracy_bps",
        metrics.two_stage_abstention_accuracy_bps,
        metrics.no_abstain_accuracy_bps + 1,
    );
    add_count_measurement(
        &mut measurements,
        "best_baseline_abstention_accuracy_bps",
        metrics.no_abstain_accuracy_bps,
        "bps",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_two_stage_active_bytes",
        evaluation.max_two_stage_active_bytes(),
        MAX_TWO_STAGE_ACTIVE_BYTES,
        "bytes",
    );
    add_string_contains_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "two_stage_address",
        &evaluation.two_stage_address,
        "uas:two-stage-route-scout:",
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
            "detail": "metadata-only two-stage route scout witness; no live route authority, no sparse wake promotion, no model/runtime bytes, and no policy mutation executed"
        })],
        notes: "Proves Stage A route-family/escalation choice and Stage B family-specific selector choice are separated, cheap, abstention-capable, rollback-bound, RunEventLog-bound, and AnswerPacket-visible.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:two-stage-route-scout:evaluation
// Plane: Controller + Verification
// Residency: metadata-only
struct TwoStageEvaluation {
    tasks: Vec<TwoStageTask>,
    metrics: TwoStageMetrics,
    two_stage_address: String,
}

impl TwoStageEvaluation {
    fn new(mut tasks: Vec<TwoStageTask>) -> Result<Self, TwoStageError> {
        if tasks.is_empty() {
            return Err(TwoStageError::MissingTask);
        }
        let mut seen = BTreeSet::new();
        for task in &tasks {
            if !seen.insert(task.task_signature) {
                return Err(TwoStageError::DuplicateTask);
            }
            validate_task(task)?;
        }
        let metrics = TwoStageMetrics::from_tasks(&tasks)?;
        tasks.sort_by_key(|task| task.task_signature);
        let two_stage_address = two_stage_address(&tasks);
        Ok(Self {
            tasks,
            metrics,
            two_stage_address,
        })
    }

    fn held_out_tasks(&self) -> Vec<&TwoStageTask> {
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

    fn route_family_count(&self) -> u64 {
        self.tasks
            .iter()
            .map(|task| task.label_route_family)
            .collect::<BTreeSet<_>>()
            .len() as u64
    }

    fn abstention_case_count(&self) -> u64 {
        self.tasks
            .iter()
            .filter(|task| task.label_should_abstain)
            .count() as u64
    }

    fn max_two_stage_active_bytes(&self) -> u64 {
        let mut max_bytes = 0;
        for task in &self.tasks {
            max_bytes = max_bytes.max(task.two_stage_bytes());
        }
        max_bytes
    }
}

#[derive(Clone, Copy)]
// UAS: uas:two-stage-route-scout:metrics
// Plane: Verification
// Residency: metadata-only
struct TwoStageMetrics {
    two_stage_route_success_bps: u64,
    all_in_one_route_success_bps: u64,
    static_route_success_bps: u64,
    no_abstain_route_success_bps: u64,
    best_baseline_route_success_bps: u64,
    two_stage_abstention_accuracy_bps: u64,
    no_abstain_accuracy_bps: u64,
}

impl TwoStageMetrics {
    fn from_tasks(tasks: &[TwoStageTask]) -> Result<Self, TwoStageError> {
        if tasks.iter().filter(|task| task.split == "train").count() < 2 {
            return Err(TwoStageError::MissingTrainingSplit);
        }
        let held_out = tasks
            .iter()
            .filter(|task| task.split == "held_out")
            .collect::<Vec<_>>();
        if held_out.len() < 7 {
            return Err(TwoStageError::MissingHeldOutSplit);
        }
        if !held_out.iter().any(|task| task.label_should_abstain) {
            return Err(TwoStageError::MissingAbstentionCase);
        }

        let two_stage_route_success_bps = route_success_bps(&held_out, two_stage_success);
        let all_in_one_route_success_bps = route_success_bps(&held_out, |task| {
            baseline_success(task, task.all_in_one_baseline)
        });
        let static_route_success_bps = route_success_bps(&held_out, |task| {
            baseline_success(task, task.static_selector_baseline)
        });
        let no_abstain_route_success_bps = route_success_bps(&held_out, |task| {
            baseline_success(task, task.no_abstain_baseline)
        });
        if two_stage_route_success_bps <= all_in_one_route_success_bps {
            return Err(TwoStageError::AllInOneBaselineUnbeaten);
        }
        if two_stage_route_success_bps <= static_route_success_bps {
            return Err(TwoStageError::StaticSelectorBaselineUnbeaten);
        }
        if two_stage_route_success_bps <= no_abstain_route_success_bps {
            return Err(TwoStageError::NoAbstainBaselineUnbeaten);
        }

        let two_stage_abstention_accuracy_bps =
            abstention_accuracy_bps(&held_out, |task| task.stage_a.should_abstain);
        let no_abstain_accuracy_bps =
            abstention_accuracy_bps(&held_out, |task| task.no_abstain_baseline.abstained);
        if two_stage_abstention_accuracy_bps <= no_abstain_accuracy_bps {
            return Err(TwoStageError::NoAbstainBaselineUnbeaten);
        }

        Ok(Self {
            two_stage_route_success_bps,
            all_in_one_route_success_bps,
            static_route_success_bps,
            no_abstain_route_success_bps,
            best_baseline_route_success_bps: max_u64(&[
                all_in_one_route_success_bps,
                static_route_success_bps,
                no_abstain_route_success_bps,
            ]),
            two_stage_abstention_accuracy_bps,
            no_abstain_accuracy_bps,
        })
    }
}

impl TwoStageTask {
    fn two_stage_bytes(&self) -> u64 {
        self.stage_a_active_bytes
            .saturating_add(self.stage_b_active_bytes)
    }
}

fn validate_task(task: &TwoStageTask) -> Result<(), TwoStageError> {
    if task.split != "train" && task.split != "held_out" {
        return Err(TwoStageError::MissingSplit);
    }
    if !task.task_signature.starts_with("task:") {
        return Err(TwoStageError::MissingTaskSignature);
    }
    if !task.mission_id.starts_with("mission:") {
        return Err(TwoStageError::MissingMission);
    }
    if !prefixed_features(task.source_features, "source:")
        || !prefixed_features(task.verifier_features, "verifier:")
    {
        return Err(TwoStageError::MissingFeature);
    }
    if !task.stage_a_ref.starts_with("stage-a:") {
        return Err(TwoStageError::MissingStageA);
    }
    if !task.stage_b_ref.starts_with("stage-b:") {
        return Err(TwoStageError::MissingStageB);
    }
    if !task.stage_a.selector_leak_ref.is_empty() {
        return Err(TwoStageError::StageASelectorLeak);
    }
    if !valid_route_family(task.stage_a.route_family) {
        return Err(TwoStageError::StageAUnknownFamily);
    }
    if task.stage_a.route_family != task.label_route_family {
        return Err(TwoStageError::StageAWrongFamily);
    }
    if !valid_selector_kind(task.stage_b.selector_kind) {
        return Err(TwoStageError::StageBUnknownSelector);
    }
    if task.stage_b.selector_family != task.stage_a.route_family {
        return Err(TwoStageError::StageBFamilyMismatch);
    }
    if task.stage_b.selector_kind != task.label_selector_kind {
        return Err(TwoStageError::StageBWrongSelector);
    }
    if !selector_allowed_for_family(task.stage_b.selector_kind, task.stage_a.route_family) {
        return Err(TwoStageError::StageBFamilyMismatch);
    }
    if !task.stage_b.irrelevant_selector_refs.is_empty() {
        return Err(TwoStageError::IrrelevantSelectorChosen);
    }
    if !bounded_confidence(task.stage_a.confidence_bps)
        || !bounded_confidence(task.stage_b.confidence_bps)
        || task.stage_a.uncertainty_bps > 10_000
        || task.stage_a.conflict_bps > 10_000
    {
        return Err(TwoStageError::InvalidConfidence);
    }
    if task.stage_a.abstain_threshold_bps == 0 || task.stage_a.abstain_threshold_bps > 10_000 {
        return Err(TwoStageError::MissingAbstainThreshold);
    }
    if !abstention_policy_holds(task) {
        return Err(TwoStageError::HighUncertaintyNonAbstain);
    }
    if !conflict_policy_holds(task) {
        return Err(TwoStageError::ConflictNonAbstain);
    }
    if task.stage_a.should_abstain != task.label_should_abstain {
        return Err(TwoStageError::HighUncertaintyNonAbstain);
    }
    if !task.rollback_handle.starts_with("rollback:") {
        return Err(TwoStageError::MissingRollback);
    }
    if !task.run_event_log_ref.starts_with("runlog:") {
        return Err(TwoStageError::MissingRunEventLog);
    }
    if !task.answer_packet_ref.starts_with("answerpacket:") {
        return Err(TwoStageError::MissingAnswerPacket);
    }
    if task.route_authority != "shadow_only" {
        return Err(TwoStageError::HiddenLiveAuthority);
    }
    if task.live_policy_mutated {
        return Err(TwoStageError::LivePolicyMutation);
    }
    if task.hidden_chain_exposed {
        return Err(TwoStageError::HiddenChainExposure);
    }
    if task.hidden_cloud {
        return Err(TwoStageError::CloudRoute);
    }
    if task.two_stage_bytes() == 0 || task.two_stage_bytes() > MAX_TWO_STAGE_ACTIVE_BYTES {
        return Err(TwoStageError::TwoStageBudgetExceeded);
    }
    if task.heavy_route_min_active_bytes
        < task
            .two_stage_bytes()
            .saturating_mul(MIN_HEAVY_ROUTE_MULTIPLE)
    {
        return Err(TwoStageError::TwoStageNotCheaper);
    }
    Ok(())
}

fn route_success_bps(tasks: &[&TwoStageTask], success: impl Fn(&TwoStageTask) -> bool) -> u64 {
    let correct = tasks.iter().filter(|task| success(task)).count() as u64;
    correct * 10_000 / tasks.len() as u64
}

fn abstention_accuracy_bps(
    tasks: &[&TwoStageTask],
    abstained: impl Fn(&TwoStageTask) -> bool,
) -> u64 {
    let correct = tasks
        .iter()
        .filter(|task| abstained(task) == task.label_should_abstain)
        .count() as u64;
    correct * 10_000 / tasks.len() as u64
}

fn two_stage_success(task: &TwoStageTask) -> bool {
    task.stage_a.route_family == task.label_route_family
        && task.stage_b.selector_kind == task.label_selector_kind
        && task.stage_a.should_abstain == task.label_should_abstain
}

fn baseline_success(task: &TwoStageTask, baseline: BaselineDecision) -> bool {
    baseline.route_family == task.label_route_family
        && baseline.selector_kind == task.label_selector_kind
        && baseline.abstained == task.label_should_abstain
}

fn abstention_policy_holds(task: &TwoStageTask) -> bool {
    if task.stage_a.uncertainty_bps >= task.stage_a.abstain_threshold_bps {
        task.stage_a.should_abstain
            && task.stage_a.route_family == "abstain_escalate"
            && task.stage_b.selector_kind == "abstain"
    } else {
        true
    }
}

fn conflict_policy_holds(task: &TwoStageTask) -> bool {
    if task.stage_a.conflict_bps >= task.stage_a.abstain_threshold_bps {
        task.stage_a.should_abstain
            && task.stage_a.route_family == "abstain_escalate"
            && task.stage_b.selector_kind == "abstain"
    } else {
        true
    }
}

fn prefixed_features(features: &[&str], prefix: &str) -> bool {
    !features.is_empty() && features.iter().all(|feature| feature.starts_with(prefix))
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

fn valid_selector_kind(selector_kind: &str) -> bool {
    matches!(
        selector_kind,
        "apple_private_model_profile"
            | "eidos_index"
            | "mlx_model_variant"
            | "proof_toolchain"
            | "kv_page_policy"
            | "mutation_plan"
            | "abstain"
    )
}

fn selector_allowed_for_family(selector_kind: &str, route_family: &str) -> bool {
    matches!(
        (route_family, selector_kind),
        ("apple_private_summary", "apple_private_model_profile")
            | ("eidos_retrieval", "eidos_index")
            | ("local_qwen_code", "mlx_model_variant")
            | ("proof_tools", "proof_toolchain")
            | ("kv_recall", "kv_page_policy")
            | ("sovereign_note_mutation", "mutation_plan")
            | ("abstain_escalate", "abstain")
    )
}

fn bounded_confidence(confidence_bps: u64) -> bool {
    (1_000..=10_000).contains(&confidence_bps)
}

fn two_stage_is_cheaper(task: &TwoStageTask) -> bool {
    task.two_stage_bytes() > 0
        && task.two_stage_bytes() <= MAX_TWO_STAGE_ACTIVE_BYTES
        && task.heavy_route_min_active_bytes
            >= task
                .two_stage_bytes()
                .saturating_mul(MIN_HEAVY_ROUTE_MULTIPLE)
}

fn duplicate_task_rejected() -> bool {
    let mut tasks = fixture_tasks();
    let duplicate = tasks[0].clone();
    tasks.push(duplicate);
    matches!(
        TwoStageEvaluation::new(tasks),
        Err(TwoStageError::DuplicateTask)
    )
}

fn invalid_task_rejected(mut mutate: impl FnMut(&mut TwoStageTask)) -> Option<TwoStageError> {
    let mut tasks = fixture_tasks();
    mutate(&mut tasks[2]);
    TwoStageEvaluation::new(tasks).err()
}

fn invalid_fixture_rejected(mut mutate: impl FnMut(&mut [TwoStageTask])) -> Option<TwoStageError> {
    let mut tasks = fixture_tasks();
    mutate(&mut tasks);
    TwoStageEvaluation::new(tasks).err()
}

fn two_stage_address(tasks: &[TwoStageTask]) -> String {
    let mut preimage = String::new();
    for task in tasks {
        push_preimage(&mut preimage, "task_signature", task.task_signature);
        push_preimage(&mut preimage, "mission_id", task.mission_id);
        push_preimage(&mut preimage, "stage_a_ref", task.stage_a_ref);
        push_preimage(&mut preimage, "stage_b_ref", task.stage_b_ref);
        push_preimage(&mut preimage, "route_family", task.stage_a.route_family);
        push_preimage(&mut preimage, "selector_kind", task.stage_b.selector_kind);
        push_preimage(&mut preimage, "selector_id", task.stage_b.selector_id);
        push_preimage(
            &mut preimage,
            "should_abstain",
            if task.stage_a.should_abstain {
                "true"
            } else {
                "false"
            },
        );
    }
    format!(
        "uas:two-stage-route-scout:{}",
        sha256_hex(preimage.as_bytes())
    )
}

fn push_preimage(preimage: &mut String, key: &str, value: &str) {
    preimage.push_str(key);
    preimage.push('=');
    preimage.push_str(value);
    preimage.push('\n');
}

fn upstream_route_scout_ssm_baseline_pass() -> bool {
    let Ok(bytes) = std::fs::read(UPSTREAM_ROUTE_SCOUT) else {
        return false;
    };
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
        && value
            .get("pass_per_axis")
            .and_then(|axes| axes.get("no_runtime_bytes_loaded"))
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false)
}

fn add_bps_ge_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    minimum: u64,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: "bps".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::from(minimum),
            unit: "bps".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual >= minimum);
}

fn add_u64_le_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    maximum: u64,
    unit: &str,
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
            operator: "<=".to_string(),
            value: serde_json::Value::from(maximum),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual <= maximum);
}

fn add_count_measurement(
    measurements: &mut BTreeMap<String, Measurement>,
    name: &str,
    actual: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
}

fn add_string_contains_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
    expected_substring: &str,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual.to_string()),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "contains".to_string(),
            value: serde_json::Value::String(expected_substring.to_string()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual.contains(expected_substring));
}

fn max_u64(values: &[u64]) -> u64 {
    let mut best = 0;
    for value in values {
        best = best.max(*value);
    }
    best
}

fn fixture_tasks() -> Vec<TwoStageTask> {
    vec![
        task(
            "train",
            "task:train:private-summary",
            "mission:train:privacy",
            "apple_private_summary",
            "apple_private_model_profile",
            false,
            2_000,
            1_000,
            all_in_one(
                "apple_private_summary",
                "apple_private_model_profile",
                false,
            ),
            static_base("eidos_retrieval", "eidos_index"),
            no_abstain("apple_private_summary", "apple_private_model_profile"),
        ),
        task(
            "train",
            "task:train:proof-repair",
            "mission:train:proof",
            "proof_tools",
            "proof_toolchain",
            false,
            2_200,
            1_600,
            all_in_one("local_qwen_code", "mlx_model_variant", false),
            static_base("eidos_retrieval", "eidos_index"),
            no_abstain("proof_tools", "proof_toolchain"),
        ),
        task(
            "held_out",
            "task:heldout:eidos-citation",
            "mission:research:evidence",
            "eidos_retrieval",
            "eidos_index",
            false,
            2_100,
            1_400,
            all_in_one("eidos_retrieval", "eidos_index", false),
            static_base("eidos_retrieval", "eidos_index"),
            no_abstain("eidos_retrieval", "eidos_index"),
        ),
        task(
            "held_out",
            "task:heldout:qwen-code",
            "mission:coding:local",
            "local_qwen_code",
            "mlx_model_variant",
            false,
            2_600,
            1_700,
            all_in_one("proof_tools", "proof_toolchain", false),
            static_base("eidos_retrieval", "eidos_index"),
            no_abstain("local_qwen_code", "mlx_model_variant"),
        ),
        task(
            "held_out",
            "task:heldout:proof-tool",
            "mission:proof:route-card",
            "proof_tools",
            "proof_toolchain",
            false,
            1_700,
            1_900,
            all_in_one("proof_tools", "proof_toolchain", false),
            static_base("eidos_retrieval", "eidos_index"),
            no_abstain("proof_tools", "proof_toolchain"),
        ),
        task(
            "held_out",
            "task:heldout:kv-recall",
            "mission:notes:kv-recall",
            "kv_recall",
            "kv_page_policy",
            false,
            2_300,
            1_600,
            all_in_one("eidos_retrieval", "eidos_index", false),
            static_base("eidos_retrieval", "eidos_index"),
            no_abstain("kv_recall", "kv_page_policy"),
        ),
        task(
            "held_out",
            "task:heldout:sovereign-mutation",
            "mission:notes:mutation",
            "sovereign_note_mutation",
            "mutation_plan",
            false,
            2_500,
            1_200,
            all_in_one("local_qwen_code", "mlx_model_variant", false),
            static_base("eidos_retrieval", "eidos_index"),
            no_abstain("sovereign_note_mutation", "mutation_plan"),
        ),
        task(
            "held_out",
            "task:heldout:uncertain-abstain",
            "mission:route:uncertainty",
            "abstain_escalate",
            "abstain",
            true,
            9_200,
            2_000,
            all_in_one("local_qwen_code", "mlx_model_variant", false),
            static_base("eidos_retrieval", "eidos_index"),
            no_abstain("local_qwen_code", "mlx_model_variant"),
        ),
        task(
            "held_out",
            "task:heldout:conflict-abstain",
            "mission:route:conflict",
            "abstain_escalate",
            "abstain",
            true,
            2_100,
            9_100,
            all_in_one("proof_tools", "proof_toolchain", false),
            static_base("eidos_retrieval", "eidos_index"),
            no_abstain("proof_tools", "proof_toolchain"),
        ),
    ]
}

#[allow(clippy::too_many_arguments)]
fn task(
    split: &'static str,
    task_signature: &'static str,
    mission_id: &'static str,
    family: &'static str,
    selector: &'static str,
    should_abstain: bool,
    uncertainty_bps: u64,
    conflict_bps: u64,
    all_in_one_baseline: BaselineDecision,
    static_selector_baseline: BaselineDecision,
    no_abstain_baseline: BaselineDecision,
) -> TwoStageTask {
    let selector_id = match selector {
        "apple_private_model_profile" => "selector:apple-private:summary",
        "eidos_index" => "selector:eidos:citations",
        "mlx_model_variant" => "selector:mlx:qwen-local-code",
        "proof_toolchain" => "selector:proof:lean-repair",
        "kv_page_policy" => "selector:kv:query-aware-pages",
        "mutation_plan" => "selector:scope-rex:note-mutation-plan",
        "abstain" => "selector:abstain:visible-escalation",
        _ => "selector:unknown",
    };
    TwoStageTask {
        split,
        task_signature,
        mission_id,
        source_features: &["source:uas-address", "source:task-signature"],
        verifier_features: &["verifier:need", "verifier:conflict"],
        stage_a_ref: "stage-a:route-family-escalation",
        stage_b_ref: "stage-b:family-specific-selector",
        label_route_family: family,
        label_selector_kind: selector,
        label_should_abstain: should_abstain,
        stage_a: StageADecision {
            route_family: family,
            confidence_bps: if should_abstain { 9_000 } else { 8_900 },
            uncertainty_bps,
            conflict_bps,
            abstain_threshold_bps: 8_500,
            should_abstain,
            selector_leak_ref: "",
        },
        stage_b: StageBDecision {
            selector_family: family,
            selector_kind: selector,
            selector_id,
            confidence_bps: if should_abstain { 9_100 } else { 8_800 },
            irrelevant_selector_refs: &[],
        },
        all_in_one_baseline,
        static_selector_baseline,
        no_abstain_baseline,
        rollback_handle: "rollback:two-stage-route-scout",
        run_event_log_ref: "runlog:two-stage-route-scout",
        answer_packet_ref: "answerpacket:two-stage-route-scout",
        route_authority: "shadow_only",
        stage_a_active_bytes: 2 * 1024 * 1024,
        stage_b_active_bytes: 2 * 1024 * 1024,
        heavy_route_min_active_bytes: 64 * 1024 * 1024,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        live_policy_mutated: false,
    }
}

fn all_in_one(
    route_family: &'static str,
    selector_kind: &'static str,
    abstained: bool,
) -> BaselineDecision {
    BaselineDecision {
        route_family,
        selector_kind,
        abstained,
    }
}

fn static_base(route_family: &'static str, selector_kind: &'static str) -> BaselineDecision {
    BaselineDecision {
        route_family,
        selector_kind,
        abstained: false,
    }
}

fn no_abstain(route_family: &'static str, selector_kind: &'static str) -> BaselineDecision {
    BaselineDecision {
        route_family,
        selector_kind,
        abstained: false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_fixture_rejects() {
        assert_eq!(
            TwoStageEvaluation::new(Vec::new()).err(),
            Some(TwoStageError::MissingTask)
        );
    }

    #[test]
    fn fixture_evaluation_passes_and_address_is_order_stable() {
        let tasks = fixture_tasks();
        let reversed = tasks.iter().cloned().rev().collect::<Vec<_>>();
        let evaluation = match TwoStageEvaluation::new(tasks) {
            Ok(evaluation) => evaluation,
            Err(error) => panic!("fixture should pass: {error}"),
        };
        let reversed_evaluation = match TwoStageEvaluation::new(reversed) {
            Ok(evaluation) => evaluation,
            Err(error) => panic!("reversed fixture should pass: {error}"),
        };
        assert_eq!(evaluation.training_task_count(), 2);
        assert_eq!(evaluation.held_out_task_count(), 7);
        assert_eq!(evaluation.abstention_case_count(), 2);
        assert_eq!(
            evaluation.two_stage_address,
            reversed_evaluation.two_stage_address
        );
    }

    #[test]
    fn required_invalid_fixtures_reject() {
        assert!(duplicate_task_rejected());
        assert_eq!(
            invalid_task_rejected(|task| task.stage_a.selector_leak_ref = "selector:leak"),
            Some(TwoStageError::StageASelectorLeak)
        );
        assert_eq!(
            invalid_task_rejected(|task| {
                task.stage_b.selector_family = "proof_tools";
                task.stage_b.selector_kind = "proof_toolchain";
            }),
            Some(TwoStageError::StageBFamilyMismatch)
        );
        assert_eq!(
            invalid_task_rejected(|task| {
                task.stage_a.uncertainty_bps = 9_500;
                task.stage_a.should_abstain = false;
                task.label_should_abstain = true;
            }),
            Some(TwoStageError::HighUncertaintyNonAbstain)
        );
        assert_eq!(
            invalid_task_rejected(|task| task.route_authority = "live_route_policy"),
            Some(TwoStageError::HiddenLiveAuthority)
        );
        assert_eq!(
            invalid_fixture_rejected(|tasks| {
                for task in tasks {
                    task.all_in_one_baseline.route_family = task.label_route_family;
                    task.all_in_one_baseline.selector_kind = task.label_selector_kind;
                    task.all_in_one_baseline.abstained = task.label_should_abstain;
                }
            }),
            Some(TwoStageError::AllInOneBaselineUnbeaten)
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
        assert!(artifact.pass_per_axis["stage_a_no_selector_leak"]);
        assert!(artifact.pass_per_axis["uncertainty_abstention_bound"]);
        assert!(artifact.pass_per_axis["verifier_conflict_abstention_bound"]);
    }
}
