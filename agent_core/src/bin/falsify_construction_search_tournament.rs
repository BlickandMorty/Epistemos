//! `falsify_construction_search_tournament` -- offline tournament witness.
//!
//! Metadata-only witness for `F-ConstructionSearchTournament`. It proves a
//! PatternBoost/Axplorer-style generate-repair-score-select loop improves
//! sparse wake plans over random generation under a fixed budget while staying
//! shadow-only, rollback-bound, AnswerPacket-visible, and zero-runtime-byte.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-ConstructionSearchTournament";
const FIXTURE_ID: &str = "construction_search_tournament_v1";
const COMMAND: &str = "Tools/falsifiers/f_construction_search_tournament.sh";
const RESULT: &str = "artifacts/falsifiers/construction_search_tournament/result.json";
const UPSTREAM_LAYER_KV_LEASE: &str = "artifacts/falsifiers/layer_kv_joint_lease/result.json";

const CURRENT_FENCE: &str = "fence:construction-search:v1:sparse-wake:layer-kv";
const MAX_GENERATION_BUDGET: u64 = 12;
const MAX_COMPUTE_STEPS: u64 = 48;
const MAX_EXPLORATION_BUDGET: u64 = 10;
const MAX_HOT_BYTES: u64 = 128 * 1024 * 1024;
const MAX_KV_BYTES: u64 = 224 * 1024 * 1024;
const MAX_COLD_BYTES: u64 = 2 * 1024 * 1024 * 1024;
const MAX_LATENCY_MS: u64 = 280;
const MAX_REPAIR_FAILURE_BPS: u64 = 2_500;
const MIN_DIVERSITY_BUCKETS: u64 = 4;
const MIN_TOURNAMENT_SUCCESS_BPS: u64 = 9_000;
const MIN_HELD_OUT_SUCCESS_BPS: u64 = 8_500;
const MAX_TOURNAMENT_METADATA_BYTES: u64 = 1_048_576;

#[cfg(test)]
const REQUIRED_AXES: &[&str] = &[
    "upstream_layer_kv_joint_lease_pass",
    "construction_search_tournament_fixture_present",
    "tournament_ids_bound",
    "mission_families_bound",
    "generation_policy_bound",
    "repair_policy_bound",
    "scoring_policy_bound",
    "selection_policy_bound",
    "random_seed_bound",
    "candidate_genomes_bound",
    "generation_trace_refs_bound",
    "repair_trace_refs_bound",
    "score_trace_refs_bound",
    "selected_winners_bound",
    "held_out_split_bound",
    "diversity_buckets_bound",
    "exploration_budget_bound",
    "fixed_budget_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "route_authority_shadow_only",
    "live_route_not_promoted",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "construction_search_tournament_address_deterministic",
    "winners_fit_hot_budget",
    "winners_fit_kv_budget",
    "winners_fit_cold_budget",
    "winner_latency_bound",
    "repair_failure_rate_bound",
    "tournament_beats_random_generation_baseline",
    "tournament_beats_greedy_baseline",
    "tournament_beats_unrepaired_baseline",
    "held_out_win_rate_bound",
    "metadata_bound",
    "duplicate_tournament_rejected",
    "duplicate_candidate_rejected",
    "missing_generation_policy_rejected",
    "missing_repair_policy_rejected",
    "missing_scoring_policy_rejected",
    "missing_selection_policy_rejected",
    "missing_candidate_rejected",
    "unrepaired_candidate_selected_rejected",
    "invalid_candidate_selected_rejected",
    "over_budget_candidate_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_live_authority_rejected",
    "live_route_promotion_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "metadata_budget_rejected",
    "random_baseline_unbeaten_rejected",
    "greedy_baseline_unbeaten_rejected",
    "unrepaired_baseline_unbeaten_rejected",
    "insufficient_diversity_rejected",
    "exploration_budget_exceeded_rejected",
    "tournament_count",
    "candidate_count",
    "repaired_candidate_count",
    "selected_winner_count",
    "held_out_case_count",
    "diversity_bucket_count",
    "repair_failure_count",
    "max_generation_budget",
    "max_compute_steps",
    "max_exploration_budget",
    "max_hot_bytes",
    "max_kv_bytes",
    "max_cold_bytes",
    "max_latency_ms",
    "max_repair_failure_bps",
    "tournament_success_bps",
    "held_out_success_bps",
    "random_generation_baseline_bps",
    "greedy_baseline_bps",
    "unrepaired_baseline_bps",
    "max_tournament_metadata_bytes",
    "construction_search_tournament_address",
];

#[derive(Clone)]
// UAS: uas:construction-search-tournament:candidate
// Plane: Assembly + Controller
// Residency: metadata-only sparse wake plan candidate; no bytes are woken.
struct TournamentCandidate {
    candidate_id: String,
    genome_address: String,
    source_trace_ref: String,
    generation_trace_ref: String,
    repair_trace_ref: String,
    score_trace_ref: String,
    diversity_bucket: String,
    generated: bool,
    repaired: bool,
    valid: bool,
    selected: bool,
    hot_bytes: u64,
    kv_bytes: u64,
    cold_bytes: u64,
    latency_ms: u64,
    quality_bps: u64,
    verifier_bps: u64,
    compatibility_fence: String,
    privacy_class: String,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    hidden_authority: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
}

#[derive(Clone)]
// UAS: uas:construction-search-tournament:fixture
// Plane: Controller + Assembly + Verification
// Residency: metadata-only construction tournament proof.
struct ConstructionSearchTournamentFixture {
    tournament_id: String,
    mission_family: String,
    upstream_layer_kv_lease_ref: String,
    generation_policy_ref: String,
    repair_policy_ref: String,
    scoring_policy_ref: String,
    selection_policy_ref: String,
    random_seed: u64,
    generation_budget: u64,
    compute_step_budget: u64,
    exploration_budget: u64,
    held_out_case_count: u64,
    tournament_success_bps: u64,
    held_out_success_bps: u64,
    random_generation_baseline_bps: u64,
    greedy_baseline_bps: u64,
    unrepaired_baseline_bps: u64,
    metadata_bytes: u64,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    route_authority: String,
    live_route_promoted: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
    candidates: Vec<TournamentCandidate>,
}

#[derive(Default, Clone, Copy)]
// UAS: uas:construction-search-tournament:metrics
// Plane: Verification
// Residency: metadata-only tournament summary.
struct TournamentMetrics {
    tournament_count: u64,
    candidate_count: u64,
    repaired_candidate_count: u64,
    selected_winner_count: u64,
    held_out_case_count: u64,
    diversity_bucket_count: u64,
    repair_failure_count: u64,
    max_generation_budget: u64,
    max_compute_steps: u64,
    max_exploration_budget: u64,
    max_hot_bytes: u64,
    max_kv_bytes: u64,
    max_cold_bytes: u64,
    max_latency_ms: u64,
    max_repair_failure_bps: u64,
    tournament_success_bps: u64,
    held_out_success_bps: u64,
    random_generation_baseline_bps: u64,
    greedy_baseline_bps: u64,
    unrepaired_baseline_bps: u64,
    max_tournament_metadata_bytes: u64,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:construction-search-tournament:error
// Plane: Verification
// Residency: metadata-only rejection reason.
enum ConstructionSearchTournamentError {
    MissingTournament,
    DuplicateTournament,
    MissingTournamentId,
    MissingMissionFamily,
    MissingUpstreamLayerKvLease,
    MissingGenerationPolicy,
    MissingRepairPolicy,
    MissingScoringPolicy,
    MissingSelectionPolicy,
    MissingRandomSeed,
    GenerationBudgetExceeded,
    ComputeStepBudgetExceeded,
    ExplorationBudgetExceeded,
    MissingHeldOutSplit,
    MissingCandidate,
    DuplicateCandidate,
    MissingCandidateId,
    MissingGenomeAddress,
    MissingSourceTrace,
    MissingGenerationTrace,
    MissingRepairTrace,
    MissingScoreTrace,
    MissingDiversityBucket,
    CandidateNotGenerated,
    MissingSelectedWinner,
    UnrepairedCandidateSelected,
    InvalidCandidateSelected,
    MissingCompatibilityFence,
    IncompatibleFence,
    InvalidPrivacyClass,
    WinnerHotBudgetExceeded,
    WinnerKvBudgetExceeded,
    WinnerColdBudgetExceeded,
    WinnerLatencyExceeded,
    RepairFailureRateTooHigh,
    InsufficientDiversity,
    RandomBaselineUnbeaten,
    GreedyBaselineUnbeaten,
    UnrepairedBaselineUnbeaten,
    HeldOutWinRateTooLow,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    HiddenLiveAuthority,
    LiveRoutePromotion,
    HiddenChainExposure,
    CloudSource,
    RuntimeBytesLoaded,
    MetadataBudgetExceeded,
}

impl std::fmt::Display for ConstructionSearchTournamentError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for ConstructionSearchTournamentError {}

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
            eprintln!("failed to create artifact: {error}");
            return std::process::ExitCode::from(2);
        }
    };
    if let Err(error) = write_artifact(&mut file, &artifact) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }

    let tournament_count = artifact
        .measurements
        .get("tournament_count")
        .and_then(|m| m.value.as_u64())
        .unwrap_or(0);
    let candidate_count = artifact
        .measurements
        .get("candidate_count")
        .and_then(|m| m.value.as_u64())
        .unwrap_or(0);
    let success_bps = artifact
        .measurements
        .get("tournament_success_bps")
        .and_then(|m| m.value.as_u64())
        .unwrap_or(0);
    let tournament_address = artifact
        .measurements
        .get("construction_search_tournament_address")
        .and_then(|m| m.value.as_str())
        .unwrap_or("unknown");
    println!(
        "{FALSIFIER_ID}: overall_pass={} tournament_count={} candidate_count={} tournament_success_bps={} tournament_address={tournament_address:?} artifact={RESULT}",
        artifact.overall_pass, tournament_count, candidate_count, success_bps
    );
    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact() -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, String> {
    let tournaments = fixture_tournaments();
    let registry = ConstructionSearchTournamentRegistry::new(tournaments.clone())
        .map_err(|e| e.to_string())?;
    let metrics = registry.metrics();
    let tournament_address = registry.tournament_address().map_err(|e| e.to_string())?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_layer_kv_joint_lease_pass",
        upstream_artifact_pass(UPSTREAM_LAYER_KV_LEASE),
    );

    for (name, pass) in registry.axis_bools(&tournament_address) {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            pass,
        );
    }
    for (name, pass) in invalid_fixture_axes(&tournaments) {
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
        "tournament_count",
        metrics.tournament_count,
        2,
        "tournament",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "candidate_count",
        metrics.candidate_count,
        10,
        "candidate",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "repaired_candidate_count",
        metrics.repaired_candidate_count,
        8,
        "candidate",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_winner_count",
        metrics.selected_winner_count,
        4,
        "winner",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_case_count",
        metrics.held_out_case_count,
        6,
        "case",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "diversity_bucket_count",
        metrics.diversity_bucket_count,
        MIN_DIVERSITY_BUCKETS,
        "bucket",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "repair_failure_count",
        metrics.repair_failure_count,
        2,
        "candidate",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_generation_budget",
        metrics.max_generation_budget,
        MAX_GENERATION_BUDGET,
        "candidate",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_compute_steps",
        metrics.max_compute_steps,
        MAX_COMPUTE_STEPS,
        "step",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_exploration_budget",
        metrics.max_exploration_budget,
        MAX_EXPLORATION_BUDGET,
        "branch",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_hot_bytes",
        metrics.max_hot_bytes,
        MAX_HOT_BYTES,
        "bytes",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_kv_bytes",
        metrics.max_kv_bytes,
        MAX_KV_BYTES,
        "bytes",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_cold_bytes",
        metrics.max_cold_bytes,
        MAX_COLD_BYTES,
        "bytes",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_latency_ms",
        metrics.max_latency_ms,
        MAX_LATENCY_MS,
        "ms",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_repair_failure_bps",
        metrics.max_repair_failure_bps,
        MAX_REPAIR_FAILURE_BPS,
        "bps",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "tournament_success_bps",
        metrics.tournament_success_bps,
        MIN_TOURNAMENT_SUCCESS_BPS,
        "bps",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_success_bps",
        metrics.held_out_success_bps,
        MIN_HELD_OUT_SUCCESS_BPS,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "random_generation_baseline_bps",
        metrics.random_generation_baseline_bps,
        metrics.tournament_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "greedy_baseline_bps",
        metrics.greedy_baseline_bps,
        metrics.tournament_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unrepaired_baseline_bps",
        metrics.unrepaired_baseline_bps,
        metrics.tournament_success_bps,
        "bps",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_tournament_metadata_bytes",
        metrics.max_tournament_metadata_bytes,
        MAX_TOURNAMENT_METADATA_BYTES,
        "bytes",
    );
    add_label_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "construction_search_tournament_address",
        &tournament_address,
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
            "kind": "metadata_only_scope",
            "detail": "ConstructionSearchTournament proves offline generate-repair-score-select shape and rejection behavior only; it wakes no bytes, mutates no live policy, and promotes no live route authority."
        })],
        notes: "metadata-only Meta Control witness; construction search stays offline/shadow-only and proves fixed-budget tournament winners beat random, greedy, and unrepaired baselines with rollback, RunEventLog, AnswerPacket, no-hidden-authority, and zero-runtime-byte guards; L1 only, not product/live sparse route evidence".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();
    Ok(artifact)
}

// UAS: uas:construction-search-tournament:registry
// Plane: Controller + Assembly + Verification
// Residency: metadata-only registry; validates tournament shape before artifact emission.
struct ConstructionSearchTournamentRegistry {
    tournaments: Vec<ConstructionSearchTournamentFixture>,
}

impl ConstructionSearchTournamentRegistry {
    fn new(
        tournaments: Vec<ConstructionSearchTournamentFixture>,
    ) -> Result<Self, ConstructionSearchTournamentError> {
        validate_tournaments(&tournaments)?;
        Ok(Self { tournaments })
    }

    fn metrics(&self) -> TournamentMetrics {
        let mut metrics = TournamentMetrics {
            tournament_count: self.tournaments.len() as u64,
            tournament_success_bps: u64::MAX,
            held_out_success_bps: u64::MAX,
            ..TournamentMetrics::default()
        };
        let mut diversity_buckets = BTreeSet::new();
        for tournament in &self.tournaments {
            metrics.held_out_case_count += tournament.held_out_case_count;
            metrics.max_generation_budget = metrics
                .max_generation_budget
                .max(tournament.generation_budget);
            metrics.max_compute_steps = metrics
                .max_compute_steps
                .max(tournament.compute_step_budget);
            metrics.max_exploration_budget = metrics
                .max_exploration_budget
                .max(tournament.exploration_budget);
            metrics.tournament_success_bps = metrics
                .tournament_success_bps
                .min(tournament.tournament_success_bps);
            metrics.held_out_success_bps = metrics
                .held_out_success_bps
                .min(tournament.held_out_success_bps);
            metrics.random_generation_baseline_bps = metrics
                .random_generation_baseline_bps
                .max(tournament.random_generation_baseline_bps);
            metrics.greedy_baseline_bps = metrics
                .greedy_baseline_bps
                .max(tournament.greedy_baseline_bps);
            metrics.unrepaired_baseline_bps = metrics
                .unrepaired_baseline_bps
                .max(tournament.unrepaired_baseline_bps);
            metrics.max_tournament_metadata_bytes = metrics
                .max_tournament_metadata_bytes
                .max(tournament.metadata_bytes);
            for candidate in &tournament.candidates {
                metrics.candidate_count += 1;
                if candidate.repaired {
                    metrics.repaired_candidate_count += 1;
                } else {
                    metrics.repair_failure_count += 1;
                }
                if candidate.selected {
                    metrics.selected_winner_count += 1;
                    metrics.max_hot_bytes = metrics.max_hot_bytes.max(candidate.hot_bytes);
                    metrics.max_kv_bytes = metrics.max_kv_bytes.max(candidate.kv_bytes);
                    metrics.max_cold_bytes = metrics.max_cold_bytes.max(candidate.cold_bytes);
                    metrics.max_latency_ms = metrics.max_latency_ms.max(candidate.latency_ms);
                }
                diversity_buckets.insert(candidate.diversity_bucket.as_str());
            }
        }
        metrics.diversity_bucket_count = diversity_buckets.len() as u64;
        if metrics.candidate_count > 0 {
            metrics.max_repair_failure_bps =
                metrics.repair_failure_count * 10_000 / metrics.candidate_count;
        }
        metrics
    }

    fn axis_bools(&self, tournament_address: &str) -> Vec<(&'static str, bool)> {
        let metrics = self.metrics();
        vec![
            (
                "construction_search_tournament_fixture_present",
                !self.tournaments.is_empty(),
            ),
            (
                "tournament_ids_bound",
                self.tournaments.iter().all(|t| !t.tournament_id.is_empty()),
            ),
            (
                "mission_families_bound",
                self.tournaments
                    .iter()
                    .all(|t| !t.mission_family.is_empty()),
            ),
            (
                "generation_policy_bound",
                self.tournaments
                    .iter()
                    .all(|t| !t.generation_policy_ref.is_empty()),
            ),
            (
                "repair_policy_bound",
                self.tournaments
                    .iter()
                    .all(|t| !t.repair_policy_ref.is_empty()),
            ),
            (
                "scoring_policy_bound",
                self.tournaments
                    .iter()
                    .all(|t| !t.scoring_policy_ref.is_empty()),
            ),
            (
                "selection_policy_bound",
                self.tournaments
                    .iter()
                    .all(|t| !t.selection_policy_ref.is_empty()),
            ),
            (
                "random_seed_bound",
                self.tournaments.iter().all(|t| t.random_seed > 0),
            ),
            (
                "candidate_genomes_bound",
                self.tournaments
                    .iter()
                    .flat_map(|t| &t.candidates)
                    .all(|c| !c.genome_address.is_empty()),
            ),
            (
                "generation_trace_refs_bound",
                self.tournaments
                    .iter()
                    .flat_map(|t| &t.candidates)
                    .all(|c| !c.generation_trace_ref.is_empty()),
            ),
            (
                "repair_trace_refs_bound",
                self.tournaments
                    .iter()
                    .flat_map(|t| &t.candidates)
                    .all(|c| !c.repair_trace_ref.is_empty()),
            ),
            (
                "score_trace_refs_bound",
                self.tournaments
                    .iter()
                    .flat_map(|t| &t.candidates)
                    .all(|c| !c.score_trace_ref.is_empty()),
            ),
            ("selected_winners_bound", metrics.selected_winner_count == 4),
            ("held_out_split_bound", metrics.held_out_case_count == 6),
            (
                "diversity_buckets_bound",
                metrics.diversity_bucket_count >= MIN_DIVERSITY_BUCKETS,
            ),
            (
                "exploration_budget_bound",
                metrics.max_exploration_budget <= MAX_EXPLORATION_BUDGET,
            ),
            (
                "fixed_budget_bound",
                metrics.max_generation_budget <= MAX_GENERATION_BUDGET
                    && metrics.max_compute_steps <= MAX_COMPUTE_STEPS,
            ),
            (
                "rollback_bound",
                self.tournaments
                    .iter()
                    .all(|t| !t.rollback_handle.is_empty())
                    && self
                        .tournaments
                        .iter()
                        .flat_map(|t| &t.candidates)
                        .filter(|c| c.selected)
                        .all(|c| !c.rollback_handle.is_empty()),
            ),
            (
                "run_event_log_bound",
                self.tournaments
                    .iter()
                    .all(|t| !t.run_event_log_ref.is_empty())
                    && self
                        .tournaments
                        .iter()
                        .flat_map(|t| &t.candidates)
                        .filter(|c| c.selected)
                        .all(|c| !c.run_event_log_ref.is_empty()),
            ),
            (
                "answer_packet_ref_bound",
                self.tournaments
                    .iter()
                    .all(|t| !t.answer_packet_ref.is_empty())
                    && self
                        .tournaments
                        .iter()
                        .flat_map(|t| &t.candidates)
                        .filter(|c| c.selected)
                        .all(|c| !c.answer_packet_ref.is_empty()),
            ),
            (
                "route_authority_shadow_only",
                self.tournaments
                    .iter()
                    .all(|t| t.route_authority == "shadow_only")
                    && self
                        .tournaments
                        .iter()
                        .flat_map(|t| &t.candidates)
                        .all(|c| !c.hidden_authority),
            ),
            (
                "live_route_not_promoted",
                self.tournaments.iter().all(|t| !t.live_route_promoted),
            ),
            (
                "no_hidden_chain",
                self.tournaments.iter().all(|t| !t.hidden_chain_exposed),
            ),
            (
                "no_hidden_cloud",
                self.tournaments.iter().all(|t| !t.hidden_cloud),
            ),
            (
                "no_runtime_bytes_loaded",
                self.tournaments.iter().all(|t| t.runtime_bytes_loaded == 0),
            ),
            (
                "construction_search_tournament_address_deterministic",
                !tournament_address.is_empty(),
            ),
            (
                "winners_fit_hot_budget",
                metrics.max_hot_bytes <= MAX_HOT_BYTES,
            ),
            (
                "winners_fit_kv_budget",
                metrics.max_kv_bytes <= MAX_KV_BYTES,
            ),
            (
                "winners_fit_cold_budget",
                metrics.max_cold_bytes <= MAX_COLD_BYTES,
            ),
            (
                "winner_latency_bound",
                metrics.max_latency_ms <= MAX_LATENCY_MS,
            ),
            (
                "repair_failure_rate_bound",
                metrics.max_repair_failure_bps <= MAX_REPAIR_FAILURE_BPS,
            ),
            (
                "tournament_beats_random_generation_baseline",
                metrics.random_generation_baseline_bps < metrics.tournament_success_bps,
            ),
            (
                "tournament_beats_greedy_baseline",
                metrics.greedy_baseline_bps < metrics.tournament_success_bps,
            ),
            (
                "tournament_beats_unrepaired_baseline",
                metrics.unrepaired_baseline_bps < metrics.tournament_success_bps,
            ),
            (
                "held_out_win_rate_bound",
                metrics.held_out_success_bps >= MIN_HELD_OUT_SUCCESS_BPS,
            ),
            (
                "metadata_bound",
                metrics.max_tournament_metadata_bytes <= MAX_TOURNAMENT_METADATA_BYTES,
            ),
        ]
    }

    fn tournament_address(&self) -> Result<String, ConstructionSearchTournamentError> {
        let mut rows = Vec::with_capacity(self.tournaments.len());
        for tournament in &self.tournaments {
            let mut candidate_ids: Vec<&str> = tournament
                .candidates
                .iter()
                .map(|candidate| candidate.candidate_id.as_str())
                .collect();
            candidate_ids.sort_unstable();
            rows.push(format!(
                "{}:{}:{}:{}:{}:{}:{}",
                tournament.tournament_id,
                tournament.mission_family,
                tournament.random_seed,
                tournament.generation_budget,
                tournament.tournament_success_bps,
                tournament.held_out_success_bps,
                candidate_ids.join(",")
            ));
        }
        rows.sort_unstable();
        Ok(format!(
            "uas:construction-search-tournament:{}",
            sha256_hex(rows.join("|").as_bytes())
        ))
    }
}

fn validate_tournaments(
    tournaments: &[ConstructionSearchTournamentFixture],
) -> Result<(), ConstructionSearchTournamentError> {
    if tournaments.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingTournament);
    }
    let mut tournament_ids = BTreeSet::new();
    let mut candidate_ids = BTreeSet::new();
    let mut all_diversity_buckets = BTreeSet::new();
    let mut selected_count = 0_u64;
    let mut repair_failures = 0_u64;
    let mut candidate_count = 0_u64;
    for tournament in tournaments {
        validate_tournament_header(tournament)?;
        if !tournament_ids.insert(tournament.tournament_id.as_str()) {
            return Err(ConstructionSearchTournamentError::DuplicateTournament);
        }
        if tournament.candidates.is_empty() {
            return Err(ConstructionSearchTournamentError::MissingCandidate);
        }
        for candidate in &tournament.candidates {
            validate_candidate(candidate)?;
            if !candidate_ids.insert(candidate.candidate_id.as_str()) {
                return Err(ConstructionSearchTournamentError::DuplicateCandidate);
            }
            candidate_count += 1;
            if !candidate.repaired {
                repair_failures += 1;
            }
            all_diversity_buckets.insert(candidate.diversity_bucket.as_str());
            if candidate.selected {
                selected_count += 1;
                validate_selected_candidate(candidate)?;
            }
        }
        validate_tournament_scores(tournament)?;
    }
    if selected_count == 0 {
        return Err(ConstructionSearchTournamentError::MissingSelectedWinner);
    }
    if all_diversity_buckets.len() < MIN_DIVERSITY_BUCKETS as usize {
        return Err(ConstructionSearchTournamentError::InsufficientDiversity);
    }
    if candidate_count == 0 {
        return Err(ConstructionSearchTournamentError::MissingCandidate);
    }
    let repair_failure_bps = repair_failures * 10_000 / candidate_count;
    if repair_failure_bps > MAX_REPAIR_FAILURE_BPS {
        return Err(ConstructionSearchTournamentError::RepairFailureRateTooHigh);
    }
    Ok(())
}

fn validate_tournament_header(
    tournament: &ConstructionSearchTournamentFixture,
) -> Result<(), ConstructionSearchTournamentError> {
    if tournament.tournament_id.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingTournamentId);
    }
    if tournament.mission_family.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingMissionFamily);
    }
    if tournament.upstream_layer_kv_lease_ref.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingUpstreamLayerKvLease);
    }
    if tournament.generation_policy_ref.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingGenerationPolicy);
    }
    if tournament.repair_policy_ref.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingRepairPolicy);
    }
    if tournament.scoring_policy_ref.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingScoringPolicy);
    }
    if tournament.selection_policy_ref.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingSelectionPolicy);
    }
    if tournament.random_seed == 0 {
        return Err(ConstructionSearchTournamentError::MissingRandomSeed);
    }
    if tournament.generation_budget == 0 || tournament.generation_budget > MAX_GENERATION_BUDGET {
        return Err(ConstructionSearchTournamentError::GenerationBudgetExceeded);
    }
    if tournament.compute_step_budget == 0 || tournament.compute_step_budget > MAX_COMPUTE_STEPS {
        return Err(ConstructionSearchTournamentError::ComputeStepBudgetExceeded);
    }
    if tournament.exploration_budget == 0 || tournament.exploration_budget > MAX_EXPLORATION_BUDGET
    {
        return Err(ConstructionSearchTournamentError::ExplorationBudgetExceeded);
    }
    if tournament.held_out_case_count == 0 {
        return Err(ConstructionSearchTournamentError::MissingHeldOutSplit);
    }
    if tournament.rollback_handle.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingRollback);
    }
    if tournament.run_event_log_ref.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingRunEventLog);
    }
    if tournament.answer_packet_ref.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingAnswerPacket);
    }
    if tournament.route_authority != "shadow_only" {
        return Err(ConstructionSearchTournamentError::HiddenLiveAuthority);
    }
    if tournament.live_route_promoted {
        return Err(ConstructionSearchTournamentError::LiveRoutePromotion);
    }
    if tournament.hidden_chain_exposed {
        return Err(ConstructionSearchTournamentError::HiddenChainExposure);
    }
    if tournament.hidden_cloud {
        return Err(ConstructionSearchTournamentError::CloudSource);
    }
    if tournament.runtime_bytes_loaded > 0 {
        return Err(ConstructionSearchTournamentError::RuntimeBytesLoaded);
    }
    if tournament.metadata_bytes > MAX_TOURNAMENT_METADATA_BYTES {
        return Err(ConstructionSearchTournamentError::MetadataBudgetExceeded);
    }
    Ok(())
}

fn validate_candidate(
    candidate: &TournamentCandidate,
) -> Result<(), ConstructionSearchTournamentError> {
    if candidate.candidate_id.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingCandidateId);
    }
    if candidate.genome_address.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingGenomeAddress);
    }
    if candidate.source_trace_ref.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingSourceTrace);
    }
    if candidate.generation_trace_ref.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingGenerationTrace);
    }
    if candidate.repair_trace_ref.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingRepairTrace);
    }
    if candidate.score_trace_ref.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingScoreTrace);
    }
    if candidate.diversity_bucket.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingDiversityBucket);
    }
    if !candidate.generated {
        return Err(ConstructionSearchTournamentError::CandidateNotGenerated);
    }
    if candidate.compatibility_fence.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingCompatibilityFence);
    }
    if candidate.compatibility_fence != CURRENT_FENCE {
        return Err(ConstructionSearchTournamentError::IncompatibleFence);
    }
    if !matches!(
        candidate.privacy_class.as_str(),
        "vault_private" | "local_only" | "proof_public"
    ) {
        return Err(ConstructionSearchTournamentError::InvalidPrivacyClass);
    }
    if candidate.hidden_authority {
        return Err(ConstructionSearchTournamentError::HiddenLiveAuthority);
    }
    if candidate.hidden_chain_exposed {
        return Err(ConstructionSearchTournamentError::HiddenChainExposure);
    }
    if candidate.hidden_cloud {
        return Err(ConstructionSearchTournamentError::CloudSource);
    }
    if candidate.runtime_bytes_loaded > 0 {
        return Err(ConstructionSearchTournamentError::RuntimeBytesLoaded);
    }
    Ok(())
}

fn validate_selected_candidate(
    candidate: &TournamentCandidate,
) -> Result<(), ConstructionSearchTournamentError> {
    if !candidate.repaired {
        return Err(ConstructionSearchTournamentError::UnrepairedCandidateSelected);
    }
    if !candidate.valid {
        return Err(ConstructionSearchTournamentError::InvalidCandidateSelected);
    }
    if candidate.quality_bps == 0 || candidate.verifier_bps == 0 {
        return Err(ConstructionSearchTournamentError::InvalidCandidateSelected);
    }
    if candidate.hot_bytes > MAX_HOT_BYTES {
        return Err(ConstructionSearchTournamentError::WinnerHotBudgetExceeded);
    }
    if candidate.kv_bytes > MAX_KV_BYTES {
        return Err(ConstructionSearchTournamentError::WinnerKvBudgetExceeded);
    }
    if candidate.cold_bytes > MAX_COLD_BYTES {
        return Err(ConstructionSearchTournamentError::WinnerColdBudgetExceeded);
    }
    if candidate.latency_ms > MAX_LATENCY_MS {
        return Err(ConstructionSearchTournamentError::WinnerLatencyExceeded);
    }
    if candidate.rollback_handle.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingRollback);
    }
    if candidate.run_event_log_ref.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingRunEventLog);
    }
    if candidate.answer_packet_ref.is_empty() {
        return Err(ConstructionSearchTournamentError::MissingAnswerPacket);
    }
    Ok(())
}

fn validate_tournament_scores(
    tournament: &ConstructionSearchTournamentFixture,
) -> Result<(), ConstructionSearchTournamentError> {
    if tournament.tournament_success_bps <= tournament.random_generation_baseline_bps {
        return Err(ConstructionSearchTournamentError::RandomBaselineUnbeaten);
    }
    if tournament.tournament_success_bps <= tournament.greedy_baseline_bps {
        return Err(ConstructionSearchTournamentError::GreedyBaselineUnbeaten);
    }
    if tournament.tournament_success_bps <= tournament.unrepaired_baseline_bps {
        return Err(ConstructionSearchTournamentError::UnrepairedBaselineUnbeaten);
    }
    if tournament.held_out_success_bps < MIN_HELD_OUT_SUCCESS_BPS {
        return Err(ConstructionSearchTournamentError::HeldOutWinRateTooLow);
    }
    Ok(())
}

fn invalid_fixture_axes(
    valid_tournaments: &[ConstructionSearchTournamentFixture],
) -> Vec<(&'static str, bool)> {
    let mut cases = Vec::with_capacity(23);
    cases.push((
        "duplicate_tournament_rejected",
        rejects(valid_tournaments, |t| {
            let duplicate = t[0].clone();
            t.push(duplicate);
        }),
    ));
    cases.push((
        "duplicate_candidate_rejected",
        rejects(valid_tournaments, |t| {
            let duplicate = t[0].candidates[0].clone();
            t[0].candidates.push(duplicate);
        }),
    ));
    cases.push((
        "missing_generation_policy_rejected",
        rejects(valid_tournaments, |t| t[0].generation_policy_ref.clear()),
    ));
    cases.push((
        "missing_repair_policy_rejected",
        rejects(valid_tournaments, |t| t[0].repair_policy_ref.clear()),
    ));
    cases.push((
        "missing_scoring_policy_rejected",
        rejects(valid_tournaments, |t| t[0].scoring_policy_ref.clear()),
    ));
    cases.push((
        "missing_selection_policy_rejected",
        rejects(valid_tournaments, |t| t[0].selection_policy_ref.clear()),
    ));
    cases.push((
        "missing_candidate_rejected",
        rejects(valid_tournaments, |t| t[0].candidates.clear()),
    ));
    cases.push((
        "unrepaired_candidate_selected_rejected",
        rejects(valid_tournaments, |t| {
            if let Some(candidate) = t[0]
                .candidates
                .iter_mut()
                .find(|candidate| candidate.selected)
            {
                candidate.repaired = false;
            }
        }),
    ));
    cases.push((
        "invalid_candidate_selected_rejected",
        rejects(valid_tournaments, |t| {
            if let Some(candidate) = t[0]
                .candidates
                .iter_mut()
                .find(|candidate| candidate.selected)
            {
                candidate.valid = false;
            }
        }),
    ));
    cases.push((
        "over_budget_candidate_rejected",
        rejects(valid_tournaments, |t| {
            if let Some(candidate) = t[0]
                .candidates
                .iter_mut()
                .find(|candidate| candidate.selected)
            {
                candidate.hot_bytes = MAX_HOT_BYTES + 1;
            }
        }),
    ));
    cases.push((
        "missing_rollback_rejected",
        rejects(valid_tournaments, |t| t[0].rollback_handle.clear()),
    ));
    cases.push((
        "missing_run_event_log_rejected",
        rejects(valid_tournaments, |t| t[0].run_event_log_ref.clear()),
    ));
    cases.push((
        "missing_answer_packet_rejected",
        rejects(valid_tournaments, |t| t[0].answer_packet_ref.clear()),
    ));
    cases.push((
        "hidden_live_authority_rejected",
        rejects(valid_tournaments, |t| {
            t[0].route_authority = "live_route".to_string()
        }),
    ));
    cases.push((
        "live_route_promotion_rejected",
        rejects(valid_tournaments, |t| t[0].live_route_promoted = true),
    ));
    cases.push((
        "hidden_chain_exposure_rejected",
        rejects(valid_tournaments, |t| t[0].hidden_chain_exposed = true),
    ));
    cases.push((
        "cloud_source_rejected",
        rejects(valid_tournaments, |t| t[0].hidden_cloud = true),
    ));
    cases.push((
        "runtime_bytes_rejected",
        rejects(valid_tournaments, |t| t[0].runtime_bytes_loaded = 1),
    ));
    cases.push((
        "metadata_budget_rejected",
        rejects(valid_tournaments, |t| {
            t[0].metadata_bytes = MAX_TOURNAMENT_METADATA_BYTES + 1
        }),
    ));
    cases.push((
        "random_baseline_unbeaten_rejected",
        rejects(valid_tournaments, |t| {
            t[0].random_generation_baseline_bps = t[0].tournament_success_bps
        }),
    ));
    cases.push((
        "greedy_baseline_unbeaten_rejected",
        rejects(valid_tournaments, |t| {
            t[0].greedy_baseline_bps = t[0].tournament_success_bps
        }),
    ));
    cases.push((
        "unrepaired_baseline_unbeaten_rejected",
        rejects(valid_tournaments, |t| {
            t[0].unrepaired_baseline_bps = t[0].tournament_success_bps
        }),
    ));
    cases.push((
        "insufficient_diversity_rejected",
        rejects(valid_tournaments, |t| {
            for candidate in t
                .iter_mut()
                .flat_map(|tournament| &mut tournament.candidates)
            {
                candidate.diversity_bucket = "collapsed".to_string();
            }
        }),
    ));
    cases.push((
        "exploration_budget_exceeded_rejected",
        rejects(valid_tournaments, |t| {
            t[0].exploration_budget = MAX_EXPLORATION_BUDGET + 1
        }),
    ));
    cases
}

fn rejects<F>(valid_tournaments: &[ConstructionSearchTournamentFixture], mutate: F) -> bool
where
    F: FnOnce(&mut Vec<ConstructionSearchTournamentFixture>),
{
    let mut invalid = valid_tournaments.to_vec();
    mutate(&mut invalid);
    validate_tournaments(&invalid).is_err()
}

fn fixture_tournaments() -> Vec<ConstructionSearchTournamentFixture> {
    vec![
        tournament_fixture(
            "tournament:local-summary",
            "mission-family:local-summary-proof-repair",
            17_021,
            9_600,
            9_100,
            5_100,
            7_200,
            6_200,
            vec![
                candidate(
                    "summary-proof-kv",
                    "coactivation-kv",
                    true,
                    true,
                    true,
                    42,
                    72,
                    420,
                    118,
                    9_500,
                    9_300,
                ),
                candidate(
                    "summary-depth-verify",
                    "depth-verifier",
                    true,
                    true,
                    true,
                    51,
                    64,
                    510,
                    132,
                    9_300,
                    9_400,
                ),
                candidate(
                    "summary-random-a",
                    "random-low-proof",
                    true,
                    false,
                    false,
                    91,
                    190,
                    1_200,
                    246,
                    5_300,
                    4_800,
                ),
                candidate(
                    "summary-repaired-alt",
                    "eidos-citation",
                    true,
                    true,
                    false,
                    67,
                    104,
                    700,
                    176,
                    8_400,
                    8_100,
                ),
                candidate(
                    "summary-recombined",
                    "transport-tight",
                    true,
                    true,
                    false,
                    58,
                    88,
                    620,
                    150,
                    8_200,
                    8_000,
                ),
            ],
        ),
        tournament_fixture(
            "tournament:proof-repair",
            "mission-family:proof-repair-citation-risk",
            33_771,
            9_400,
            8_900,
            4_700,
            7_000,
            5_900,
            vec![
                candidate(
                    "repair-proof-lane",
                    "proof-pressure",
                    true,
                    true,
                    true,
                    46,
                    80,
                    480,
                    126,
                    9_300,
                    9_200,
                ),
                candidate(
                    "repair-kv-evidence",
                    "kv-evidence",
                    true,
                    true,
                    true,
                    54,
                    92,
                    560,
                    144,
                    9_100,
                    9_000,
                ),
                candidate(
                    "repair-random-b",
                    "random-unsupported",
                    true,
                    false,
                    false,
                    98,
                    210,
                    1_420,
                    262,
                    4_900,
                    4_500,
                ),
                candidate(
                    "repair-greedy-heavy",
                    "greedy-heavy",
                    true,
                    true,
                    false,
                    130,
                    230,
                    2_200,
                    290,
                    8_700,
                    8_500,
                ),
                candidate(
                    "repair-ablation-alt",
                    "ablation-alt",
                    true,
                    true,
                    false,
                    64,
                    96,
                    640,
                    164,
                    8_300,
                    8_000,
                ),
            ],
        ),
    ]
}

fn tournament_fixture(
    tournament_id: &str,
    mission_family: &str,
    random_seed: u64,
    tournament_success_bps: u64,
    held_out_success_bps: u64,
    random_generation_baseline_bps: u64,
    greedy_baseline_bps: u64,
    unrepaired_baseline_bps: u64,
    candidates: Vec<TournamentCandidate>,
) -> ConstructionSearchTournamentFixture {
    ConstructionSearchTournamentFixture {
        tournament_id: tournament_id.to_string(),
        mission_family: mission_family.to_string(),
        upstream_layer_kv_lease_ref: UPSTREAM_LAYER_KV_LEASE.to_string(),
        generation_policy_ref: "policy:patternboost-generate:v1".to_string(),
        repair_policy_ref: "policy:constraint-repair:v1".to_string(),
        scoring_policy_ref: "policy:verifier-budget-score:v1".to_string(),
        selection_policy_ref: "policy:pareto-elite-select:v1".to_string(),
        random_seed,
        generation_budget: 5,
        compute_step_budget: 32,
        exploration_budget: 6,
        held_out_case_count: 3,
        tournament_success_bps,
        held_out_success_bps,
        random_generation_baseline_bps,
        greedy_baseline_bps,
        unrepaired_baseline_bps,
        metadata_bytes: 92_000,
        rollback_handle: format!("rollback:{tournament_id}:shadow-only"),
        run_event_log_ref: format!("run-event-log:{tournament_id}:construction-search"),
        answer_packet_ref: format!("answer-packet:{tournament_id}:construction-search"),
        route_authority: "shadow_only".to_string(),
        live_route_promoted: false,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        runtime_bytes_loaded: 0,
        candidates,
    }
}

fn candidate(
    suffix: &str,
    diversity_bucket: &str,
    generated: bool,
    repaired: bool,
    selected: bool,
    hot_mib: u64,
    kv_mib: u64,
    cold_mib: u64,
    latency_ms: u64,
    quality_bps: u64,
    verifier_bps: u64,
) -> TournamentCandidate {
    TournamentCandidate {
        candidate_id: format!("candidate:{suffix}"),
        genome_address: format!("uas:sparse-wake-genome:{}", sha256_hex(suffix.as_bytes())),
        source_trace_ref: format!("source-trace:{suffix}"),
        generation_trace_ref: format!("generation-trace:{suffix}"),
        repair_trace_ref: format!("repair-trace:{suffix}"),
        score_trace_ref: format!("score-trace:{suffix}"),
        diversity_bucket: diversity_bucket.to_string(),
        generated,
        repaired,
        valid: repaired,
        selected,
        hot_bytes: hot_mib * 1024 * 1024,
        kv_bytes: kv_mib * 1024 * 1024,
        cold_bytes: cold_mib * 1024 * 1024,
        latency_ms,
        quality_bps,
        verifier_bps,
        compatibility_fence: CURRENT_FENCE.to_string(),
        privacy_class: "vault_private".to_string(),
        rollback_handle: format!("rollback:candidate:{suffix}"),
        run_event_log_ref: format!("run-event-log:candidate:{suffix}"),
        answer_packet_ref: format!("answer-packet:candidate:{suffix}"),
        hidden_authority: false,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        runtime_bytes_loaded: 0,
    }
}

fn upstream_artifact_pass(path: &str) -> bool {
    let Ok(bytes) = std::fs::read(path) else {
        return false;
    };
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
}

fn add_u64_lte_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    unit: &str,
) {
    add_u64_axis(
        measurements,
        thresholds,
        pass_per_axis,
        name,
        actual,
        "<=",
        expected,
        unit,
    );
}

fn add_u64_gte_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    unit: &str,
) {
    add_u64_axis(
        measurements,
        thresholds,
        pass_per_axis,
        name,
        actual,
        ">=",
        expected,
        unit,
    );
}

fn add_u64_lt_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    unit: &str,
) {
    add_u64_axis(
        measurements,
        thresholds,
        pass_per_axis,
        name,
        actual,
        "<",
        expected,
        unit,
    );
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    operator: &str,
    expected: u64,
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
            operator: operator.to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    let passed = match operator {
        "<=" => actual <= expected,
        ">=" => actual >= expected,
        "<" => actual < expected,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), passed);
}

fn add_label_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "label".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "nonempty".to_string(),
            value: serde_json::Value::String("nonempty".to_string()),
            unit: "label".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), !value.is_empty());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_fixture_rejects() {
        assert_eq!(
            validate_tournaments(&[]).err(),
            Some(ConstructionSearchTournamentError::MissingTournament)
        );
    }

    #[test]
    fn invalid_fixture_cases_reject() {
        let tournaments = fixture_tournaments();
        for (axis, passed) in invalid_fixture_axes(&tournaments) {
            assert!(passed, "{axis} should reject");
        }
    }

    #[test]
    fn tournament_address_is_order_stable() {
        let registry = ConstructionSearchTournamentRegistry::new(fixture_tournaments()).unwrap();
        let address = registry.tournament_address().unwrap();
        let mut reversed = fixture_tournaments();
        reversed.reverse();
        for tournament in &mut reversed {
            tournament.candidates.reverse();
        }
        let reversed_registry = ConstructionSearchTournamentRegistry::new(reversed).unwrap();
        assert_eq!(address, reversed_registry.tournament_address().unwrap());
    }

    #[test]
    fn artifact_contains_required_axes() {
        let artifact = build_artifact().expect("artifact builds");
        for axis in REQUIRED_AXES {
            assert!(
                artifact.measurements.contains_key(*axis),
                "missing measurement {axis}"
            );
            assert!(
                artifact.acceptance_thresholds.contains_key(*axis),
                "missing threshold {axis}"
            );
            assert!(
                artifact.pass_per_axis.contains_key(*axis),
                "missing pass axis {axis}"
            );
        }
    }
}
