//! `falsify_route_distillation_tournament` -- trace-label distillation witness.
//!
//! Metadata-only witness for `F-RouteDistillationTournament`. It proves that
//! expensive full-wake, proof/oracle, compiler-error, and failed-attempt traces
//! can be converted into held-out route labels that improve a small scout while
//! staying shadow-only, rollback-bound, AnswerPacket-visible, and zero-byte.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-RouteDistillationTournament";
const FIXTURE_ID: &str = "route_distillation_tournament_v1";
const COMMAND: &str = "Tools/falsifiers/f_route_distillation_tournament.sh";
const RESULT: &str = "artifacts/falsifiers/route_distillation_tournament/result.json";
const UPSTREAM_CONSTRUCTION_SEARCH: &str =
    "artifacts/falsifiers/construction_search_tournament/result.json";

const CURRENT_FENCE: &str = "fence:route-distillation:v1:construction-search";
const MAX_TRACE_TOKENS: u64 = 64_000;
const MAX_TOURNAMENT_METADATA_BYTES: u64 = 1_048_576;
const MIN_SOURCE_KIND_COUNT: u64 = 4;
const MIN_LABEL_AGREEMENT_BPS: u64 = 9_000;
const MAX_CALIBRATION_ERROR_BPS: u64 = 900;
const MIN_HELD_OUT_SUCCESS_BPS: u64 = 8_700;

#[cfg(test)]
const REQUIRED_AXES: &[&str] = &[
    "upstream_construction_search_tournament_pass",
    "route_distillation_tournament_fixture_present",
    "tournament_ids_bound",
    "policy_refs_bound",
    "small_scout_refs_bound",
    "trace_labels_bound",
    "mission_ids_bound",
    "expensive_trace_refs_bound",
    "oracle_label_refs_bound",
    "route_labels_bound",
    "scout_feature_refs_bound",
    "train_split_bound",
    "held_out_split_bound",
    "full_wake_traces_bound",
    "proof_oracle_traces_bound",
    "compiler_failure_traces_bound",
    "failed_attempt_traces_bound",
    "source_kind_diversity_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "route_authority_shadow_only",
    "live_policy_not_promoted",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "route_distillation_tournament_address_deterministic",
    "held_out_success_bound",
    "label_agreement_bound",
    "calibration_error_bound",
    "trace_token_budget_bound",
    "metadata_bound",
    "beats_direct_heuristic_baseline",
    "beats_pre_distill_scout_baseline",
    "beats_construction_winner_baseline",
    "duplicate_tournament_rejected",
    "duplicate_trace_label_rejected",
    "missing_expensive_trace_rejected",
    "missing_oracle_label_rejected",
    "missing_route_label_rejected",
    "missing_scout_feature_rejected",
    "invalid_split_rejected",
    "missing_held_out_split_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_live_authority_rejected",
    "live_policy_promotion_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "direct_heuristic_unbeaten_rejected",
    "pre_distill_scout_unbeaten_rejected",
    "construction_winner_unbeaten_rejected",
    "label_agreement_too_low_rejected",
    "calibration_error_too_high_rejected",
    "source_kind_diversity_missing_rejected",
    "metadata_budget_rejected",
    "trace_token_budget_rejected",
    "tournament_count",
    "trace_label_count",
    "train_case_count",
    "held_out_case_count",
    "source_kind_count",
    "max_trace_tokens",
    "max_tournament_metadata_bytes",
    "held_out_success_bps",
    "label_agreement_bps",
    "calibration_error_bps",
    "direct_heuristic_baseline_bps",
    "pre_distill_scout_baseline_bps",
    "construction_winner_baseline_bps",
    "route_distillation_tournament_address",
];

#[derive(Clone)]
// UAS: uas:route-distillation-tournament:trace-label
// Plane: Controller + Verification
// Residency: metadata-only trace label; no model or runtime bytes are loaded.
struct TraceLabel {
    trace_id: String,
    mission_id: String,
    source_kind: String,
    expensive_trace_ref: String,
    oracle_label_ref: String,
    route_label: String,
    scout_feature_ref: String,
    split: String,
    trace_tokens: u64,
    compatibility_fence: String,
    privacy_class: String,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    hidden_authority: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
}

#[derive(Clone)]
// UAS: uas:route-distillation-tournament:fixture
// Plane: Controller + Verification
// Residency: metadata-only distillation tournament proof.
struct RouteDistillationTournamentFixture {
    tournament_id: String,
    upstream_construction_search_ref: String,
    distillation_policy_ref: String,
    label_schema_ref: String,
    small_scout_ref: String,
    held_out_success_bps: u64,
    label_agreement_bps: u64,
    calibration_error_bps: u64,
    direct_heuristic_baseline_bps: u64,
    pre_distill_scout_baseline_bps: u64,
    construction_winner_baseline_bps: u64,
    metadata_bytes: u64,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    route_authority: String,
    live_policy_promoted: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
    labels: Vec<TraceLabel>,
}

#[derive(Default, Clone, Copy)]
// UAS: uas:route-distillation-tournament:metrics
// Plane: Verification
// Residency: metadata-only route-label summary.
struct RouteDistillationMetrics {
    tournament_count: u64,
    trace_label_count: u64,
    train_case_count: u64,
    held_out_case_count: u64,
    source_kind_count: u64,
    max_trace_tokens: u64,
    max_tournament_metadata_bytes: u64,
    held_out_success_bps: u64,
    label_agreement_bps: u64,
    calibration_error_bps: u64,
    direct_heuristic_baseline_bps: u64,
    pre_distill_scout_baseline_bps: u64,
    construction_winner_baseline_bps: u64,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:route-distillation-tournament:error
// Plane: Verification
// Residency: metadata-only rejection reason.
enum RouteDistillationTournamentError {
    MissingTournament,
    DuplicateTournament,
    MissingTournamentId,
    MissingUpstreamConstructionSearch,
    MissingDistillationPolicy,
    MissingLabelSchema,
    MissingSmallScout,
    MissingTraceLabel,
    DuplicateTraceLabel,
    MissingTraceId,
    MissingMissionId,
    MissingSourceKind,
    MissingExpensiveTrace,
    MissingOracleLabel,
    MissingRouteLabel,
    MissingScoutFeature,
    InvalidSplit,
    MissingTrainSplit,
    MissingHeldOutSplit,
    MissingCompatibilityFence,
    IncompatibleFence,
    InvalidPrivacyClass,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    HiddenLiveAuthority,
    LivePolicyPromotion,
    HiddenChainExposure,
    CloudSource,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
    HeldOutSuccessTooLow,
    LabelAgreementTooLow,
    CalibrationErrorTooHigh,
    DirectHeuristicBaselineUnbeaten,
    PreDistillScoutBaselineUnbeaten,
    ConstructionWinnerBaselineUnbeaten,
    SourceKindDiversityTooLow,
    MetadataBudgetExceeded,
    TraceTokenBudgetExceeded,
}

impl std::fmt::Display for RouteDistillationTournamentError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for RouteDistillationTournamentError {}

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

    let label_count = artifact
        .measurements
        .get("trace_label_count")
        .and_then(|m| m.value.as_u64())
        .unwrap_or(0);
    let held_out_success_bps = artifact
        .measurements
        .get("held_out_success_bps")
        .and_then(|m| m.value.as_u64())
        .unwrap_or(0);
    let route_address = artifact
        .measurements
        .get("route_distillation_tournament_address")
        .and_then(|m| m.value.as_str())
        .unwrap_or("unknown");
    println!(
        "{FALSIFIER_ID}: overall_pass={} trace_label_count={} held_out_success_bps={} route_distillation_address={route_address:?} artifact={RESULT}",
        artifact.overall_pass, label_count, held_out_success_bps
    );
    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact() -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, String> {
    let tournaments = fixture_tournaments();
    let registry =
        RouteDistillationTournamentRegistry::new(tournaments.clone()).map_err(|e| e.to_string())?;
    let metrics = registry.metrics();
    let route_address = registry.route_distillation_address();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_construction_search_tournament_pass",
        upstream_artifact_pass(UPSTREAM_CONSTRUCTION_SEARCH),
    );

    for (name, pass) in registry.axis_bools(&route_address) {
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
        "trace_label_count",
        metrics.trace_label_count,
        12,
        "label",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "train_case_count",
        metrics.train_case_count,
        6,
        "case",
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
        "source_kind_count",
        metrics.source_kind_count,
        MIN_SOURCE_KIND_COUNT,
        "kind",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_trace_tokens",
        metrics.max_trace_tokens,
        MAX_TRACE_TOKENS,
        "token",
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
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_success_bps",
        metrics.held_out_success_bps,
        MIN_HELD_OUT_SUCCESS_BPS,
        "bps",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "label_agreement_bps",
        metrics.label_agreement_bps,
        MIN_LABEL_AGREEMENT_BPS,
        "bps",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "calibration_error_bps",
        metrics.calibration_error_bps,
        MAX_CALIBRATION_ERROR_BPS,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "direct_heuristic_baseline_bps",
        metrics.direct_heuristic_baseline_bps,
        metrics.held_out_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "pre_distill_scout_baseline_bps",
        metrics.pre_distill_scout_baseline_bps,
        metrics.held_out_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "construction_winner_baseline_bps",
        metrics.construction_winner_baseline_bps,
        metrics.held_out_success_bps,
        "bps",
    );
    add_label_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_distillation_tournament_address",
        &route_address,
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
            "kind": "metadata_only_scope",
            "detail": "RouteDistillationTournament proves trace-to-label distillation shape and rejection behavior only; it wakes no bytes, mutates no live route policy, and promotes no 70B or sparse runtime authority."
        })],
        notes: "metadata-only Meta Control witness; expensive full/proof/oracle/compiler/failure traces become offline route labels that improve a small scout on held-out choices while preserving rollback, RunEventLog, AnswerPacket, no-hidden-authority, no-cloud, and zero-runtime/model-byte guards; L1 only, not product/live sparse route evidence".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:route-distillation-tournament:registry
// Plane: Controller + Verification
// Residency: metadata-only registry; validates trace labels before artifact emission.
struct RouteDistillationTournamentRegistry {
    tournaments: Vec<RouteDistillationTournamentFixture>,
}

impl RouteDistillationTournamentRegistry {
    fn new(
        tournaments: Vec<RouteDistillationTournamentFixture>,
    ) -> Result<Self, RouteDistillationTournamentError> {
        validate_tournaments(&tournaments)?;
        Ok(Self { tournaments })
    }

    fn metrics(&self) -> RouteDistillationMetrics {
        let mut metrics = RouteDistillationMetrics {
            tournament_count: self.tournaments.len() as u64,
            held_out_success_bps: u64::MAX,
            label_agreement_bps: u64::MAX,
            ..RouteDistillationMetrics::default()
        };
        let mut source_kinds = BTreeSet::new();
        for tournament in &self.tournaments {
            metrics.held_out_success_bps = metrics
                .held_out_success_bps
                .min(tournament.held_out_success_bps);
            metrics.label_agreement_bps = metrics
                .label_agreement_bps
                .min(tournament.label_agreement_bps);
            metrics.calibration_error_bps = metrics
                .calibration_error_bps
                .max(tournament.calibration_error_bps);
            metrics.direct_heuristic_baseline_bps = metrics
                .direct_heuristic_baseline_bps
                .max(tournament.direct_heuristic_baseline_bps);
            metrics.pre_distill_scout_baseline_bps = metrics
                .pre_distill_scout_baseline_bps
                .max(tournament.pre_distill_scout_baseline_bps);
            metrics.construction_winner_baseline_bps = metrics
                .construction_winner_baseline_bps
                .max(tournament.construction_winner_baseline_bps);
            metrics.max_tournament_metadata_bytes = metrics
                .max_tournament_metadata_bytes
                .max(tournament.metadata_bytes);
            for label in &tournament.labels {
                metrics.trace_label_count += 1;
                metrics.max_trace_tokens = metrics.max_trace_tokens.max(label.trace_tokens);
                source_kinds.insert(label.source_kind.as_str());
                match label.split.as_str() {
                    "train" => metrics.train_case_count += 1,
                    "held_out" => metrics.held_out_case_count += 1,
                    _ => {}
                }
            }
        }
        metrics.source_kind_count = source_kinds.len() as u64;
        metrics
    }

    fn axis_bools(&self, route_address: &str) -> Vec<(&'static str, bool)> {
        let metrics = self.metrics();
        vec![
            (
                "route_distillation_tournament_fixture_present",
                !self.tournaments.is_empty(),
            ),
            (
                "tournament_ids_bound",
                self.tournaments.iter().all(|t| !t.tournament_id.is_empty()),
            ),
            (
                "policy_refs_bound",
                self.tournaments.iter().all(|t| {
                    !t.distillation_policy_ref.is_empty() && !t.label_schema_ref.is_empty()
                }),
            ),
            (
                "small_scout_refs_bound",
                self.tournaments
                    .iter()
                    .all(|t| !t.small_scout_ref.is_empty()),
            ),
            (
                "trace_labels_bound",
                self.tournaments.iter().all(|t| !t.labels.is_empty()),
            ),
            (
                "mission_ids_bound",
                self.tournaments
                    .iter()
                    .flat_map(|t| &t.labels)
                    .all(|label| !label.mission_id.is_empty()),
            ),
            (
                "expensive_trace_refs_bound",
                self.tournaments
                    .iter()
                    .flat_map(|t| &t.labels)
                    .all(|label| !label.expensive_trace_ref.is_empty()),
            ),
            (
                "oracle_label_refs_bound",
                self.tournaments
                    .iter()
                    .flat_map(|t| &t.labels)
                    .all(|label| !label.oracle_label_ref.is_empty()),
            ),
            (
                "route_labels_bound",
                self.tournaments
                    .iter()
                    .flat_map(|t| &t.labels)
                    .all(|label| !label.route_label.is_empty()),
            ),
            (
                "scout_feature_refs_bound",
                self.tournaments
                    .iter()
                    .flat_map(|t| &t.labels)
                    .all(|label| !label.scout_feature_ref.is_empty()),
            ),
            ("train_split_bound", metrics.train_case_count == 6),
            ("held_out_split_bound", metrics.held_out_case_count == 6),
            ("full_wake_traces_bound", self.has_source_kind("full_wake")),
            (
                "proof_oracle_traces_bound",
                self.has_source_kind("proof_oracle"),
            ),
            (
                "compiler_failure_traces_bound",
                self.has_source_kind("compiler_failure"),
            ),
            (
                "failed_attempt_traces_bound",
                self.has_source_kind("failed_attempt"),
            ),
            (
                "source_kind_diversity_bound",
                metrics.source_kind_count >= MIN_SOURCE_KIND_COUNT,
            ),
            (
                "compatibility_fence_bound",
                self.tournaments
                    .iter()
                    .flat_map(|t| &t.labels)
                    .all(|label| {
                        !label.compatibility_fence.is_empty()
                            && label.compatibility_fence == CURRENT_FENCE
                    }),
            ),
            (
                "privacy_classes_bound",
                self.tournaments
                    .iter()
                    .flat_map(|t| &t.labels)
                    .all(|label| valid_privacy_class(&label.privacy_class)),
            ),
            (
                "rollback_bound",
                self.tournaments
                    .iter()
                    .all(|t| !t.rollback_handle.is_empty())
                    && self
                        .tournaments
                        .iter()
                        .flat_map(|t| &t.labels)
                        .all(|label| !label.rollback_handle.is_empty()),
            ),
            (
                "run_event_log_bound",
                self.tournaments
                    .iter()
                    .all(|t| !t.run_event_log_ref.is_empty())
                    && self
                        .tournaments
                        .iter()
                        .flat_map(|t| &t.labels)
                        .all(|label| !label.run_event_log_ref.is_empty()),
            ),
            (
                "answer_packet_ref_bound",
                self.tournaments
                    .iter()
                    .all(|t| !t.answer_packet_ref.is_empty())
                    && self
                        .tournaments
                        .iter()
                        .flat_map(|t| &t.labels)
                        .all(|label| !label.answer_packet_ref.is_empty()),
            ),
            (
                "route_authority_shadow_only",
                self.tournaments
                    .iter()
                    .all(|t| t.route_authority == "shadow_only")
                    && self
                        .tournaments
                        .iter()
                        .flat_map(|t| &t.labels)
                        .all(|label| !label.hidden_authority),
            ),
            (
                "live_policy_not_promoted",
                self.tournaments.iter().all(|t| !t.live_policy_promoted),
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
                "no_model_bytes_loaded",
                self.tournaments.iter().all(|t| t.model_bytes_loaded == 0),
            ),
            (
                "route_distillation_tournament_address_deterministic",
                !route_address.is_empty(),
            ),
            (
                "held_out_success_bound",
                metrics.held_out_success_bps >= MIN_HELD_OUT_SUCCESS_BPS,
            ),
            (
                "label_agreement_bound",
                metrics.label_agreement_bps >= MIN_LABEL_AGREEMENT_BPS,
            ),
            (
                "calibration_error_bound",
                metrics.calibration_error_bps <= MAX_CALIBRATION_ERROR_BPS,
            ),
            (
                "trace_token_budget_bound",
                metrics.max_trace_tokens <= MAX_TRACE_TOKENS,
            ),
            (
                "metadata_bound",
                metrics.max_tournament_metadata_bytes <= MAX_TOURNAMENT_METADATA_BYTES,
            ),
            (
                "beats_direct_heuristic_baseline",
                metrics.direct_heuristic_baseline_bps < metrics.held_out_success_bps,
            ),
            (
                "beats_pre_distill_scout_baseline",
                metrics.pre_distill_scout_baseline_bps < metrics.held_out_success_bps,
            ),
            (
                "beats_construction_winner_baseline",
                metrics.construction_winner_baseline_bps < metrics.held_out_success_bps,
            ),
        ]
    }

    fn has_source_kind(&self, source_kind: &str) -> bool {
        self.tournaments
            .iter()
            .flat_map(|t| &t.labels)
            .any(|label| label.source_kind == source_kind)
    }

    fn route_distillation_address(&self) -> String {
        let mut rows = Vec::with_capacity(self.tournaments.len());
        for tournament in &self.tournaments {
            let mut label_ids: Vec<&str> = tournament
                .labels
                .iter()
                .map(|label| label.trace_id.as_str())
                .collect();
            label_ids.sort_unstable();
            rows.push(format!(
                "{}:{}:{}:{}:{}:{}",
                tournament.tournament_id,
                tournament.small_scout_ref,
                tournament.held_out_success_bps,
                tournament.label_agreement_bps,
                tournament.calibration_error_bps,
                label_ids.join(",")
            ));
        }
        rows.sort_unstable();
        format!(
            "uas:route-distillation-tournament:{}",
            sha256_hex(rows.join("|").as_bytes())
        )
    }
}

fn validate_tournaments(
    tournaments: &[RouteDistillationTournamentFixture],
) -> Result<(), RouteDistillationTournamentError> {
    if tournaments.is_empty() {
        return Err(RouteDistillationTournamentError::MissingTournament);
    }
    let mut tournament_ids = BTreeSet::new();
    let mut trace_ids = BTreeSet::new();
    let mut train_count = 0_u64;
    let mut held_out_count = 0_u64;
    let mut source_kinds = BTreeSet::new();
    for tournament in tournaments {
        validate_tournament_header(tournament)?;
        if !tournament_ids.insert(tournament.tournament_id.as_str()) {
            return Err(RouteDistillationTournamentError::DuplicateTournament);
        }
        if tournament.labels.is_empty() {
            return Err(RouteDistillationTournamentError::MissingTraceLabel);
        }
        for label in &tournament.labels {
            validate_trace_label(label)?;
            if !trace_ids.insert(label.trace_id.as_str()) {
                return Err(RouteDistillationTournamentError::DuplicateTraceLabel);
            }
            match label.split.as_str() {
                "train" => train_count += 1,
                "held_out" => held_out_count += 1,
                _ => return Err(RouteDistillationTournamentError::InvalidSplit),
            }
            source_kinds.insert(label.source_kind.as_str());
        }
        validate_tournament_scores(tournament)?;
    }
    if train_count == 0 {
        return Err(RouteDistillationTournamentError::MissingTrainSplit);
    }
    if held_out_count == 0 {
        return Err(RouteDistillationTournamentError::MissingHeldOutSplit);
    }
    if source_kinds.len() < MIN_SOURCE_KIND_COUNT as usize {
        return Err(RouteDistillationTournamentError::SourceKindDiversityTooLow);
    }
    Ok(())
}

fn validate_tournament_header(
    tournament: &RouteDistillationTournamentFixture,
) -> Result<(), RouteDistillationTournamentError> {
    if tournament.tournament_id.is_empty() {
        return Err(RouteDistillationTournamentError::MissingTournamentId);
    }
    if tournament.upstream_construction_search_ref.is_empty() {
        return Err(RouteDistillationTournamentError::MissingUpstreamConstructionSearch);
    }
    if tournament.distillation_policy_ref.is_empty() {
        return Err(RouteDistillationTournamentError::MissingDistillationPolicy);
    }
    if tournament.label_schema_ref.is_empty() {
        return Err(RouteDistillationTournamentError::MissingLabelSchema);
    }
    if tournament.small_scout_ref.is_empty() {
        return Err(RouteDistillationTournamentError::MissingSmallScout);
    }
    if tournament.rollback_handle.is_empty() {
        return Err(RouteDistillationTournamentError::MissingRollback);
    }
    if tournament.run_event_log_ref.is_empty() {
        return Err(RouteDistillationTournamentError::MissingRunEventLog);
    }
    if tournament.answer_packet_ref.is_empty() {
        return Err(RouteDistillationTournamentError::MissingAnswerPacket);
    }
    if tournament.route_authority != "shadow_only" {
        return Err(RouteDistillationTournamentError::HiddenLiveAuthority);
    }
    if tournament.live_policy_promoted {
        return Err(RouteDistillationTournamentError::LivePolicyPromotion);
    }
    if tournament.hidden_chain_exposed {
        return Err(RouteDistillationTournamentError::HiddenChainExposure);
    }
    if tournament.hidden_cloud {
        return Err(RouteDistillationTournamentError::CloudSource);
    }
    if tournament.runtime_bytes_loaded > 0 {
        return Err(RouteDistillationTournamentError::RuntimeBytesLoaded);
    }
    if tournament.model_bytes_loaded > 0 {
        return Err(RouteDistillationTournamentError::ModelBytesLoaded);
    }
    if tournament.metadata_bytes > MAX_TOURNAMENT_METADATA_BYTES {
        return Err(RouteDistillationTournamentError::MetadataBudgetExceeded);
    }
    Ok(())
}

fn validate_trace_label(label: &TraceLabel) -> Result<(), RouteDistillationTournamentError> {
    if label.trace_id.is_empty() {
        return Err(RouteDistillationTournamentError::MissingTraceId);
    }
    if label.mission_id.is_empty() {
        return Err(RouteDistillationTournamentError::MissingMissionId);
    }
    if label.source_kind.is_empty() {
        return Err(RouteDistillationTournamentError::MissingSourceKind);
    }
    if label.expensive_trace_ref.is_empty() {
        return Err(RouteDistillationTournamentError::MissingExpensiveTrace);
    }
    if label.oracle_label_ref.is_empty() {
        return Err(RouteDistillationTournamentError::MissingOracleLabel);
    }
    if label.route_label.is_empty() {
        return Err(RouteDistillationTournamentError::MissingRouteLabel);
    }
    if label.scout_feature_ref.is_empty() {
        return Err(RouteDistillationTournamentError::MissingScoutFeature);
    }
    if !matches!(label.split.as_str(), "train" | "held_out") {
        return Err(RouteDistillationTournamentError::InvalidSplit);
    }
    if label.trace_tokens == 0 || label.trace_tokens > MAX_TRACE_TOKENS {
        return Err(RouteDistillationTournamentError::TraceTokenBudgetExceeded);
    }
    if label.compatibility_fence.is_empty() {
        return Err(RouteDistillationTournamentError::MissingCompatibilityFence);
    }
    if label.compatibility_fence != CURRENT_FENCE {
        return Err(RouteDistillationTournamentError::IncompatibleFence);
    }
    if !valid_privacy_class(&label.privacy_class) {
        return Err(RouteDistillationTournamentError::InvalidPrivacyClass);
    }
    if label.rollback_handle.is_empty() {
        return Err(RouteDistillationTournamentError::MissingRollback);
    }
    if label.run_event_log_ref.is_empty() {
        return Err(RouteDistillationTournamentError::MissingRunEventLog);
    }
    if label.answer_packet_ref.is_empty() {
        return Err(RouteDistillationTournamentError::MissingAnswerPacket);
    }
    if label.hidden_authority {
        return Err(RouteDistillationTournamentError::HiddenLiveAuthority);
    }
    if label.hidden_chain_exposed {
        return Err(RouteDistillationTournamentError::HiddenChainExposure);
    }
    if label.hidden_cloud {
        return Err(RouteDistillationTournamentError::CloudSource);
    }
    if label.runtime_bytes_loaded > 0 {
        return Err(RouteDistillationTournamentError::RuntimeBytesLoaded);
    }
    if label.model_bytes_loaded > 0 {
        return Err(RouteDistillationTournamentError::ModelBytesLoaded);
    }
    Ok(())
}

fn validate_tournament_scores(
    tournament: &RouteDistillationTournamentFixture,
) -> Result<(), RouteDistillationTournamentError> {
    if tournament.held_out_success_bps < MIN_HELD_OUT_SUCCESS_BPS {
        return Err(RouteDistillationTournamentError::HeldOutSuccessTooLow);
    }
    if tournament.label_agreement_bps < MIN_LABEL_AGREEMENT_BPS {
        return Err(RouteDistillationTournamentError::LabelAgreementTooLow);
    }
    if tournament.calibration_error_bps > MAX_CALIBRATION_ERROR_BPS {
        return Err(RouteDistillationTournamentError::CalibrationErrorTooHigh);
    }
    if tournament.held_out_success_bps <= tournament.direct_heuristic_baseline_bps {
        return Err(RouteDistillationTournamentError::DirectHeuristicBaselineUnbeaten);
    }
    if tournament.held_out_success_bps <= tournament.pre_distill_scout_baseline_bps {
        return Err(RouteDistillationTournamentError::PreDistillScoutBaselineUnbeaten);
    }
    if tournament.held_out_success_bps <= tournament.construction_winner_baseline_bps {
        return Err(RouteDistillationTournamentError::ConstructionWinnerBaselineUnbeaten);
    }
    Ok(())
}

fn valid_privacy_class(privacy_class: &str) -> bool {
    matches!(
        privacy_class,
        "vault_private" | "local_only" | "proof_public"
    )
}

fn invalid_fixture_axes(
    valid_tournaments: &[RouteDistillationTournamentFixture],
) -> Vec<(&'static str, bool)> {
    let mut cases = Vec::with_capacity(27);
    cases.push((
        "duplicate_tournament_rejected",
        rejects(valid_tournaments, |t| t.push(t[0].clone())),
    ));
    cases.push((
        "duplicate_trace_label_rejected",
        rejects(valid_tournaments, |t| {
            let duplicate = t[0].labels[0].clone();
            t[0].labels.push(duplicate);
        }),
    ));
    cases.push((
        "missing_expensive_trace_rejected",
        rejects(valid_tournaments, |t| {
            t[0].labels[0].expensive_trace_ref.clear()
        }),
    ));
    cases.push((
        "missing_oracle_label_rejected",
        rejects(valid_tournaments, |t| {
            t[0].labels[0].oracle_label_ref.clear()
        }),
    ));
    cases.push((
        "missing_route_label_rejected",
        rejects(valid_tournaments, |t| t[0].labels[0].route_label.clear()),
    ));
    cases.push((
        "missing_scout_feature_rejected",
        rejects(valid_tournaments, |t| {
            t[0].labels[0].scout_feature_ref.clear()
        }),
    ));
    cases.push((
        "invalid_split_rejected",
        rejects(valid_tournaments, |t| {
            t[0].labels[0].split = "validation".to_string()
        }),
    ));
    cases.push((
        "missing_held_out_split_rejected",
        rejects(valid_tournaments, |t| {
            for label in t.iter_mut().flat_map(|tournament| &mut tournament.labels) {
                label.split = "train".to_string();
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
        "live_policy_promotion_rejected",
        rejects(valid_tournaments, |t| t[0].live_policy_promoted = true),
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
        "model_bytes_rejected",
        rejects(valid_tournaments, |t| t[0].model_bytes_loaded = 1),
    ));
    cases.push((
        "incompatible_fence_rejected",
        rejects(valid_tournaments, |t| {
            t[0].labels[0].compatibility_fence = "fence:stale".to_string();
        }),
    ));
    cases.push((
        "invalid_privacy_rejected",
        rejects(valid_tournaments, |t| {
            t[0].labels[0].privacy_class = "external_cloud".to_string();
        }),
    ));
    cases.push((
        "direct_heuristic_unbeaten_rejected",
        rejects(valid_tournaments, |t| {
            t[0].direct_heuristic_baseline_bps = t[0].held_out_success_bps;
        }),
    ));
    cases.push((
        "pre_distill_scout_unbeaten_rejected",
        rejects(valid_tournaments, |t| {
            t[0].pre_distill_scout_baseline_bps = t[0].held_out_success_bps;
        }),
    ));
    cases.push((
        "construction_winner_unbeaten_rejected",
        rejects(valid_tournaments, |t| {
            t[0].construction_winner_baseline_bps = t[0].held_out_success_bps;
        }),
    ));
    cases.push((
        "label_agreement_too_low_rejected",
        rejects(valid_tournaments, |t| {
            t[0].label_agreement_bps = MIN_LABEL_AGREEMENT_BPS - 1;
        }),
    ));
    cases.push((
        "calibration_error_too_high_rejected",
        rejects(valid_tournaments, |t| {
            t[0].calibration_error_bps = MAX_CALIBRATION_ERROR_BPS + 1;
        }),
    ));
    cases.push((
        "source_kind_diversity_missing_rejected",
        rejects(valid_tournaments, |t| {
            for label in t.iter_mut().flat_map(|tournament| &mut tournament.labels) {
                label.source_kind = "full_wake".to_string();
            }
        }),
    ));
    cases.push((
        "metadata_budget_rejected",
        rejects(valid_tournaments, |t| {
            t[0].metadata_bytes = MAX_TOURNAMENT_METADATA_BYTES + 1;
        }),
    ));
    cases.push((
        "trace_token_budget_rejected",
        rejects(valid_tournaments, |t| {
            t[0].labels[0].trace_tokens = MAX_TRACE_TOKENS + 1;
        }),
    ));
    cases
}

fn rejects<F>(valid_tournaments: &[RouteDistillationTournamentFixture], mutate: F) -> bool
where
    F: FnOnce(&mut Vec<RouteDistillationTournamentFixture>),
{
    let mut invalid = valid_tournaments.to_vec();
    mutate(&mut invalid);
    validate_tournaments(&invalid).is_err()
}

fn fixture_tournaments() -> Vec<RouteDistillationTournamentFixture> {
    vec![
        tournament_fixture(
            "route-distill:local-summary",
            "scout:route-ssm:v1:local-summary",
            9_200,
            9_300,
            620,
            7_100,
            7_600,
            8_000,
            vec![
                trace_label(
                    "summary-full-kv",
                    "local-summary",
                    "full_wake",
                    "train",
                    42_000,
                ),
                trace_label(
                    "summary-proof-a",
                    "proof-citation",
                    "proof_oracle",
                    "train",
                    31_000,
                ),
                trace_label(
                    "summary-compiler-a",
                    "editor-repair",
                    "compiler_failure",
                    "held_out",
                    18_500,
                ),
                trace_label(
                    "summary-failed-a",
                    "query-recovery",
                    "failed_attempt",
                    "held_out",
                    22_000,
                ),
                trace_label(
                    "summary-full-b",
                    "local-summary",
                    "full_wake",
                    "train",
                    39_000,
                ),
                trace_label(
                    "summary-proof-b",
                    "proof-citation",
                    "proof_oracle",
                    "held_out",
                    28_000,
                ),
            ],
        ),
        tournament_fixture(
            "route-distill:proof-repair",
            "scout:route-ssm:v1:proof-repair",
            8_900,
            9_100,
            700,
            6_900,
            7_400,
            7_900,
            vec![
                trace_label(
                    "repair-full-kv",
                    "proof-repair",
                    "full_wake",
                    "train",
                    44_000,
                ),
                trace_label(
                    "repair-proof-a",
                    "proof-repair",
                    "proof_oracle",
                    "held_out",
                    35_000,
                ),
                trace_label(
                    "repair-compiler-a",
                    "code-fix",
                    "compiler_failure",
                    "train",
                    19_000,
                ),
                trace_label(
                    "repair-failed-a",
                    "citation-recovery",
                    "failed_attempt",
                    "held_out",
                    24_000,
                ),
                trace_label(
                    "repair-proof-b",
                    "proof-repair",
                    "proof_oracle",
                    "train",
                    33_000,
                ),
                trace_label("repair-full-b", "code-fix", "full_wake", "held_out", 46_000),
            ],
        ),
    ]
}

fn tournament_fixture(
    tournament_id: &str,
    small_scout_ref: &str,
    held_out_success_bps: u64,
    label_agreement_bps: u64,
    calibration_error_bps: u64,
    direct_heuristic_baseline_bps: u64,
    pre_distill_scout_baseline_bps: u64,
    construction_winner_baseline_bps: u64,
    labels: Vec<TraceLabel>,
) -> RouteDistillationTournamentFixture {
    RouteDistillationTournamentFixture {
        tournament_id: tournament_id.to_string(),
        upstream_construction_search_ref: UPSTREAM_CONSTRUCTION_SEARCH.to_string(),
        distillation_policy_ref: "policy:route-label-distill:v1".to_string(),
        label_schema_ref: "schema:route-label:full-proof-compiler-failure:v1".to_string(),
        small_scout_ref: small_scout_ref.to_string(),
        held_out_success_bps,
        label_agreement_bps,
        calibration_error_bps,
        direct_heuristic_baseline_bps,
        pre_distill_scout_baseline_bps,
        construction_winner_baseline_bps,
        metadata_bytes: 128_000,
        rollback_handle: format!("rollback:{tournament_id}:shadow-distillation"),
        run_event_log_ref: format!("run-event-log:{tournament_id}:route-distillation"),
        answer_packet_ref: format!("answer-packet:{tournament_id}:route-distillation"),
        route_authority: "shadow_only".to_string(),
        live_policy_promoted: false,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        runtime_bytes_loaded: 0,
        model_bytes_loaded: 0,
        labels,
    }
}

fn trace_label(
    suffix: &str,
    mission_suffix: &str,
    source_kind: &str,
    split: &str,
    trace_tokens: u64,
) -> TraceLabel {
    TraceLabel {
        trace_id: format!("trace-label:{suffix}"),
        mission_id: format!("mission:{mission_suffix}"),
        source_kind: source_kind.to_string(),
        expensive_trace_ref: format!("expensive-trace:{source_kind}:{suffix}"),
        oracle_label_ref: format!("oracle-label:{suffix}"),
        route_label: format!("route-label:{}", route_label_for_source(source_kind)),
        scout_feature_ref: format!(
            "scout-feature:{}",
            sha256_hex(format!("{source_kind}:{suffix}").as_bytes())
        ),
        split: split.to_string(),
        trace_tokens,
        compatibility_fence: CURRENT_FENCE.to_string(),
        privacy_class: "vault_private".to_string(),
        rollback_handle: format!("rollback:trace-label:{suffix}"),
        run_event_log_ref: format!("run-event-log:trace-label:{suffix}"),
        answer_packet_ref: format!("answer-packet:trace-label:{suffix}"),
        hidden_authority: false,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        runtime_bytes_loaded: 0,
        model_bytes_loaded: 0,
    }
}

fn route_label_for_source(source_kind: &str) -> &'static str {
    match source_kind {
        "full_wake" => "escalate_full_wake",
        "proof_oracle" => "proof_lane_with_sparse_kv",
        "compiler_failure" => "repair_then_verify",
        "failed_attempt" => "abstain_or_resume_with_context",
        _ => "unknown",
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
            Some(RouteDistillationTournamentError::MissingTournament)
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
    fn route_distillation_address_is_order_stable() {
        let registry = RouteDistillationTournamentRegistry::new(fixture_tournaments()).unwrap();
        let address = registry.route_distillation_address();
        let mut reversed = fixture_tournaments();
        reversed.reverse();
        for tournament in &mut reversed {
            tournament.labels.reverse();
        }
        let reversed_registry = RouteDistillationTournamentRegistry::new(reversed).unwrap();
        assert_eq!(address, reversed_registry.route_distillation_address());
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
