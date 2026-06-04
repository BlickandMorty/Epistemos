//! `falsify_verifier_regret_fast_weights` -- fast-weight route-regret witness.
//!
//! Metadata-only witness for `F-VerifierRegretFastWeights`. It proves
//! verifier-regret fast-weight updates are bounded, session/document/project
//! scoped, resettable, TTL-limited, shadow-only, rollback-bound, and useful on
//! held-out route choices before any consolidation. It never mutates base
//! weights, promotes live policy, wakes runtime bytes, or loads model bytes.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-VerifierRegretFastWeights";
const FIXTURE_ID: &str = "verifier_regret_fast_weights_v1";
const COMMAND: &str = "Tools/falsifiers/f_verifier_regret_fast_weights.sh";
const RESULT: &str = "artifacts/falsifiers/verifier_regret_fast_weights/result.json";
const UPSTREAM_PROOF_PRESSURE: &str = "artifacts/falsifiers/proof_pressure_signal/result.json";

const CURRENT_FENCE: &str = "fence:verifier-regret-fast-weights:v1:proof-pressure";
const MAX_FAST_WEIGHT_TTL_MS: u64 = 90_000;
const MIN_FAST_WEIGHT_TTL_MS: u64 = 5_000;
const DRIFT_BOUND_BPS: u64 = 850;
const MAX_ROUTE_LOGIT_DELTA_BPS: u64 = 700;
const MAX_PAGE_THRESHOLD_DELTA_BPS: u64 = 600;
const MAX_DEPTH_THRESHOLD_DELTA_BPS: u64 = 500;
const MAX_VERIFIER_PRIOR_DELTA_BPS: u64 = 650;
const MAX_TOURNAMENT_TEMPERATURE_DELTA_BPS: u64 = 450;
const MAX_DELTA_METADATA_BYTES: u64 = 512 * 1024;
const MIN_HELD_OUT_ROUTE_SUCCESS_BPS: u64 = 9_000;
const MIN_REGRET_REDUCTION_BPS: u64 = 1_000;
const MIN_ANSWER_PACKET_COVERAGE_BPS: u64 = 10_000;

#[cfg(test)]
const REQUIRED_AXES: &[&str] = &[
    "upstream_proof_pressure_signal_pass",
    "fast_weight_fixture_present",
    "fixture_ids_bound",
    "update_ids_bound",
    "scopes_bound",
    "base_policy_digests_bound",
    "fast_weight_delta_refs_bound",
    "update_rules_bound",
    "verifier_regret_refs_bound",
    "trace_surprise_refs_bound",
    "affected_policy_fields_bound",
    "splits_bound",
    "route_logit_delta_bound",
    "page_threshold_delta_bound",
    "depth_threshold_delta_bound",
    "verifier_prior_delta_bound",
    "tournament_temperature_delta_bound",
    "drift_bounds_bound",
    "ttl_bound",
    "reset_handles_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "held_out_result_refs_bound",
    "consolidation_candidates_bound",
    "consolidation_not_promoted",
    "route_authority_shadow_only",
    "fast_weights_session_local",
    "fast_weights_resettable",
    "ttl_not_expired",
    "drift_within_bound",
    "held_out_route_choice_improved",
    "route_choice_regret_reduced",
    "answer_packet_coverage_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "no_base_weight_mutation",
    "no_live_policy_promotion",
    "no_hidden_route_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "verifier_regret_fast_weights_address_deterministic",
    "metadata_bound",
    "beats_static_policy_baseline",
    "beats_no_fast_weight_baseline",
    "beats_stale_fast_weight_baseline",
    "beats_unbounded_delta_baseline",
    "duplicate_fixture_rejected",
    "missing_fixture_id_rejected",
    "missing_upstream_proof_pressure_rejected",
    "missing_shadow_policy_rejected",
    "missing_update_rejected",
    "duplicate_update_rejected",
    "missing_update_id_rejected",
    "missing_scope_rejected",
    "invalid_scope_rejected",
    "missing_base_policy_digest_rejected",
    "missing_delta_ref_rejected",
    "missing_update_rule_rejected",
    "missing_verifier_regret_rejected",
    "missing_trace_surprise_rejected",
    "missing_affected_policy_field_rejected",
    "invalid_policy_field_rejected",
    "route_logit_delta_overflow_rejected",
    "page_threshold_delta_overflow_rejected",
    "depth_threshold_delta_overflow_rejected",
    "verifier_prior_delta_overflow_rejected",
    "tournament_temperature_delta_overflow_rejected",
    "missing_drift_bound_rejected",
    "drift_overflow_rejected",
    "missing_ttl_rejected",
    "ttl_expired_rejected",
    "missing_reset_handle_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "missing_held_out_result_rejected",
    "missing_consolidation_candidate_rejected",
    "missing_held_out_split_rejected",
    "invalid_split_rejected",
    "consolidation_promotion_rejected",
    "base_weight_mutation_rejected",
    "live_policy_promotion_rejected",
    "hidden_route_authority_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "static_policy_unbeaten_rejected",
    "no_fast_weight_unbeaten_rejected",
    "stale_fast_weight_unbeaten_rejected",
    "unbounded_delta_unbeaten_rejected",
    "metadata_budget_rejected",
    "fixture_count",
    "update_count",
    "scope_count",
    "affected_policy_field_count",
    "held_out_case_count",
    "min_ttl_ms",
    "max_ttl_ms",
    "max_drift_bps",
    "drift_bound_bps",
    "held_out_route_success_bps",
    "route_regret_reduction_bps",
    "answer_packet_coverage_bps",
    "static_policy_baseline_bps",
    "no_fast_weight_baseline_bps",
    "stale_fast_weight_baseline_bps",
    "unbounded_delta_baseline_bps",
    "max_delta_metadata_bytes",
    "verifier_regret_fast_weights_address",
];

#[derive(Clone)]
// UAS: uas:verifier-regret-fast-weight:update
// Plane: Controller + Verification
// Residency: metadata-only selector delta; no base/model/runtime bytes.
struct FastWeightUpdate {
    update_id: String,
    scope: String,
    base_policy_digest: String,
    fast_weight_delta_ref: String,
    update_rule: String,
    verifier_regret_ref: String,
    trace_surprise_ref: String,
    affected_policy_fields: Vec<String>,
    route_logit_delta_bps: u64,
    page_threshold_delta_bps: u64,
    depth_threshold_delta_bps: u64,
    verifier_prior_delta_bps: u64,
    tournament_temperature_delta_bps: u64,
    drift_bound_bps: u64,
    observed_drift_bps: u64,
    ttl_ms: u64,
    age_ms: u64,
    reset_handle: String,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    held_out_result_ref: String,
    consolidation_candidate_ref: String,
    route_success_before_bps: u64,
    route_success_after_bps: u64,
    route_regret_before_bps: u64,
    route_regret_after_bps: u64,
    compatibility_fence: String,
    privacy_class: String,
    split: String,
    delta_metadata_bytes: u64,
    route_authority: String,
    base_weight_mutated: bool,
    live_policy_promoted: bool,
    consolidation_promoted: bool,
    hidden_route_authority: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
}

#[derive(Clone)]
// UAS: uas:verifier-regret-fast-weight:fixture
// Plane: Controller + Verification
// Residency: metadata-only fast-weight route-regret fixture.
struct FastWeightFixture {
    fixture_id: String,
    upstream_proof_pressure_ref: String,
    shadow_policy_ref: String,
    answer_packet_coverage_bps: u64,
    static_policy_baseline_bps: u64,
    no_fast_weight_baseline_bps: u64,
    stale_fast_weight_baseline_bps: u64,
    unbounded_delta_baseline_bps: u64,
    updates: Vec<FastWeightUpdate>,
}

#[derive(Default)]
// UAS: uas:verifier-regret-fast-weight:metrics
// Plane: Verification
// Residency: aggregate metadata only.
struct FastWeightMetrics {
    fixture_count: u64,
    update_count: u64,
    scope_count: u64,
    affected_policy_field_count: u64,
    held_out_case_count: u64,
    min_ttl_ms: u64,
    max_ttl_ms: u64,
    max_drift_bps: u64,
    held_out_route_success_bps: u64,
    route_regret_reduction_bps: u64,
    answer_packet_coverage_bps: u64,
    static_policy_baseline_bps: u64,
    no_fast_weight_baseline_bps: u64,
    stale_fast_weight_baseline_bps: u64,
    unbounded_delta_baseline_bps: u64,
    max_delta_metadata_bytes: u64,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:verifier-regret-fast-weight:error
// Plane: Verification
// Residency: metadata-only rejection taxonomy.
enum FastWeightError {
    MissingFixture,
    DuplicateFixture,
    MissingFixtureId,
    MissingUpstreamProofPressure,
    MissingShadowPolicy,
    MissingUpdate,
    DuplicateUpdate,
    MissingUpdateId,
    MissingScope,
    InvalidScope,
    MissingBasePolicyDigest,
    MissingDeltaRef,
    MissingUpdateRule,
    MissingVerifierRegret,
    MissingTraceSurprise,
    MissingPolicyField,
    InvalidPolicyField,
    RouteLogitDeltaOverflow,
    PageThresholdDeltaOverflow,
    DepthThresholdDeltaOverflow,
    VerifierPriorDeltaOverflow,
    TournamentTemperatureDeltaOverflow,
    MissingDriftBound,
    DriftOverflow,
    MissingTtl,
    TtlExpired,
    MissingResetHandle,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    MissingHeldOutResult,
    MissingConsolidationCandidate,
    ConsolidationPromotion,
    BaseWeightMutation,
    LivePolicyPromotion,
    HiddenRouteAuthority,
    HiddenChainExposure,
    CloudSource,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
    IncompatibleFence,
    InvalidPrivacy,
    MissingHeldOutSplit,
    InvalidSplit,
    StaticPolicyBaselineUnbeaten,
    NoFastWeightBaselineUnbeaten,
    StaleFastWeightBaselineUnbeaten,
    UnboundedDeltaBaselineUnbeaten,
    MetadataBudget,
}

impl std::fmt::Display for FastWeightError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for FastWeightError {}

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

    let update_count = artifact
        .measurements
        .get("update_count")
        .and_then(|m| m.value.as_u64())
        .unwrap_or(0);
    let held_out = artifact
        .measurements
        .get("held_out_route_success_bps")
        .and_then(|m| m.value.as_u64())
        .unwrap_or(0);
    let address = artifact
        .measurements
        .get("verifier_regret_fast_weights_address")
        .and_then(|m| m.value.as_str())
        .unwrap_or("unknown");
    println!(
        "{FALSIFIER_ID}: overall_pass={} update_count={} held_out_route_success_bps={} verifier_regret_fast_weights_address={address:?} artifact={RESULT}",
        artifact.overall_pass, update_count, held_out
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact() -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, String> {
    let fixtures = fixture_fast_weights();
    let registry = FastWeightRegistry::new(fixtures.clone()).map_err(|error| error.to_string())?;
    let metrics = registry.metrics();
    let address = registry.address();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_proof_pressure_signal_pass",
        upstream_artifact_pass(UPSTREAM_PROOF_PRESSURE),
    );
    for (name, passed) in registry.axis_bools(&address) {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }
    for (name, passed) in invalid_fixture_axes(&fixtures) {
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
        "fixture_count",
        metrics.fixture_count,
        2,
        "fixture",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "update_count",
        metrics.update_count,
        10,
        "update",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "scope_count",
        metrics.scope_count,
        3,
        "scope",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "affected_policy_field_count",
        metrics.affected_policy_field_count,
        5,
        "field",
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
        "min_ttl_ms",
        metrics.min_ttl_ms,
        MIN_FAST_WEIGHT_TTL_MS,
        "ms",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_ttl_ms",
        metrics.max_ttl_ms,
        MAX_FAST_WEIGHT_TTL_MS,
        "ms",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_drift_bps",
        metrics.max_drift_bps,
        DRIFT_BOUND_BPS,
        "bps",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "drift_bound_bps",
        DRIFT_BOUND_BPS,
        DRIFT_BOUND_BPS,
        "bps",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_route_success_bps",
        metrics.held_out_route_success_bps,
        MIN_HELD_OUT_ROUTE_SUCCESS_BPS,
        "bps",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_regret_reduction_bps",
        metrics.route_regret_reduction_bps,
        MIN_REGRET_REDUCTION_BPS,
        "bps",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "answer_packet_coverage_bps",
        metrics.answer_packet_coverage_bps,
        MIN_ANSWER_PACKET_COVERAGE_BPS,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "static_policy_baseline_bps",
        metrics.static_policy_baseline_bps,
        metrics.held_out_route_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_fast_weight_baseline_bps",
        metrics.no_fast_weight_baseline_bps,
        metrics.held_out_route_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "stale_fast_weight_baseline_bps",
        metrics.stale_fast_weight_baseline_bps,
        metrics.held_out_route_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unbounded_delta_baseline_bps",
        metrics.unbounded_delta_baseline_bps,
        metrics.held_out_route_success_bps,
        "bps",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_delta_metadata_bytes",
        metrics.max_delta_metadata_bytes,
        MAX_DELTA_METADATA_BYTES,
        "bytes",
    );
    add_label_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_regret_fast_weights_address",
        &address,
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
            "detail": "VerifierRegretFastWeights proves bounded shadow selector-policy deltas only; it does not mutate base model weights, consolidate policy, change live routing, wake runtime bytes, or promote product capability."
        })],
        notes: "metadata-only Meta Control witness; verifier-regret fast weights are scoped, bounded, resettable, TTL-limited, rollback-bound, RunEventLog/AnswerPacket-visible, held-out useful, shadow-only, and blocked from base-weight mutation, live policy promotion, hidden authority, hidden chain, cloud, runtime bytes, and model bytes; L1 only".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:verifier-regret-fast-weight:registry
// Plane: Controller + Verification
// Residency: metadata-only registry.
struct FastWeightRegistry {
    fixtures: Vec<FastWeightFixture>,
}

impl FastWeightRegistry {
    fn new(fixtures: Vec<FastWeightFixture>) -> Result<Self, FastWeightError> {
        validate_fixtures(&fixtures)?;
        Ok(Self { fixtures })
    }

    fn metrics(&self) -> FastWeightMetrics {
        let mut metrics = FastWeightMetrics {
            fixture_count: self.fixtures.len() as u64,
            min_ttl_ms: u64::MAX,
            held_out_route_success_bps: u64::MAX,
            route_regret_reduction_bps: u64::MAX,
            answer_packet_coverage_bps: u64::MAX,
            ..FastWeightMetrics::default()
        };
        let mut scopes = BTreeSet::new();
        let mut fields = BTreeSet::new();
        for fixture in &self.fixtures {
            metrics.answer_packet_coverage_bps = metrics
                .answer_packet_coverage_bps
                .min(fixture.answer_packet_coverage_bps);
            metrics.static_policy_baseline_bps = metrics
                .static_policy_baseline_bps
                .max(fixture.static_policy_baseline_bps);
            metrics.no_fast_weight_baseline_bps = metrics
                .no_fast_weight_baseline_bps
                .max(fixture.no_fast_weight_baseline_bps);
            metrics.stale_fast_weight_baseline_bps = metrics
                .stale_fast_weight_baseline_bps
                .max(fixture.stale_fast_weight_baseline_bps);
            metrics.unbounded_delta_baseline_bps = metrics
                .unbounded_delta_baseline_bps
                .max(fixture.unbounded_delta_baseline_bps);
            for update in &fixture.updates {
                metrics.update_count += 1;
                metrics.min_ttl_ms = metrics.min_ttl_ms.min(update.ttl_ms);
                metrics.max_ttl_ms = metrics.max_ttl_ms.max(update.ttl_ms);
                metrics.max_drift_bps = metrics.max_drift_bps.max(update.observed_drift_bps);
                metrics.held_out_route_success_bps = metrics
                    .held_out_route_success_bps
                    .min(update.route_success_after_bps);
                metrics.route_regret_reduction_bps = metrics.route_regret_reduction_bps.min(
                    update
                        .route_regret_before_bps
                        .saturating_sub(update.route_regret_after_bps),
                );
                metrics.max_delta_metadata_bytes = metrics
                    .max_delta_metadata_bytes
                    .max(update.delta_metadata_bytes);
                if update.split == "held_out" {
                    metrics.held_out_case_count += 1;
                }
                scopes.insert(update.scope.as_str());
                for field in &update.affected_policy_fields {
                    fields.insert(field.as_str());
                }
            }
        }
        metrics.scope_count = scopes.len() as u64;
        metrics.affected_policy_field_count = fields.len() as u64;
        metrics
    }

    fn axis_bools(&self, address: &str) -> Vec<(&'static str, bool)> {
        let metrics = self.metrics();
        vec![
            ("fast_weight_fixture_present", !self.fixtures.is_empty()),
            (
                "fixture_ids_bound",
                self.fixtures
                    .iter()
                    .all(|fixture| !fixture.fixture_id.is_empty()),
            ),
            (
                "update_ids_bound",
                self.updates().all(|update| !update.update_id.is_empty()),
            ),
            (
                "scopes_bound",
                self.updates().all(|update| valid_scope(&update.scope)),
            ),
            (
                "base_policy_digests_bound",
                self.updates()
                    .all(|update| valid_digest(&update.base_policy_digest)),
            ),
            (
                "fast_weight_delta_refs_bound",
                self.updates()
                    .all(|update| update.fast_weight_delta_ref.starts_with("delta:")),
            ),
            (
                "update_rules_bound",
                self.updates()
                    .all(|update| update.update_rule.starts_with("rule:")),
            ),
            (
                "verifier_regret_refs_bound",
                self.updates()
                    .all(|update| update.verifier_regret_ref.starts_with("regret:")),
            ),
            (
                "trace_surprise_refs_bound",
                self.updates()
                    .all(|update| update.trace_surprise_ref.starts_with("trace:")),
            ),
            (
                "affected_policy_fields_bound",
                self.updates().all(|update| {
                    !update.affected_policy_fields.is_empty()
                        && update
                            .affected_policy_fields
                            .iter()
                            .all(|field| valid_policy_field(field))
                }),
            ),
            (
                "splits_bound",
                self.updates().all(|update| valid_split(&update.split)),
            ),
            (
                "route_logit_delta_bound",
                self.updates()
                    .all(|update| update.route_logit_delta_bps <= MAX_ROUTE_LOGIT_DELTA_BPS),
            ),
            (
                "page_threshold_delta_bound",
                self.updates()
                    .all(|update| update.page_threshold_delta_bps <= MAX_PAGE_THRESHOLD_DELTA_BPS),
            ),
            (
                "depth_threshold_delta_bound",
                self.updates().all(|update| {
                    update.depth_threshold_delta_bps <= MAX_DEPTH_THRESHOLD_DELTA_BPS
                }),
            ),
            (
                "verifier_prior_delta_bound",
                self.updates()
                    .all(|update| update.verifier_prior_delta_bps <= MAX_VERIFIER_PRIOR_DELTA_BPS),
            ),
            (
                "tournament_temperature_delta_bound",
                self.updates().all(|update| {
                    update.tournament_temperature_delta_bps <= MAX_TOURNAMENT_TEMPERATURE_DELTA_BPS
                }),
            ),
            (
                "drift_bounds_bound",
                self.updates()
                    .all(|update| update.drift_bound_bps == DRIFT_BOUND_BPS),
            ),
            (
                "ttl_bound",
                self.updates().all(|update| {
                    update.ttl_ms >= MIN_FAST_WEIGHT_TTL_MS
                        && update.ttl_ms <= MAX_FAST_WEIGHT_TTL_MS
                }),
            ),
            (
                "reset_handles_bound",
                self.updates()
                    .all(|update| update.reset_handle.starts_with("reset:")),
            ),
            (
                "rollback_bound",
                self.updates()
                    .all(|update| update.rollback_handle.starts_with("rollback:")),
            ),
            (
                "run_event_log_bound",
                self.updates()
                    .all(|update| update.run_event_log_ref.starts_with("runlog:")),
            ),
            (
                "answer_packet_ref_bound",
                self.updates()
                    .all(|update| update.answer_packet_ref.starts_with("answer-packet:")),
            ),
            (
                "held_out_result_refs_bound",
                self.updates()
                    .all(|update| update.held_out_result_ref.starts_with("heldout:")),
            ),
            (
                "consolidation_candidates_bound",
                self.updates().all(|update| {
                    update
                        .consolidation_candidate_ref
                        .starts_with("consolidation-candidate:")
                }),
            ),
            (
                "consolidation_not_promoted",
                self.updates().all(|update| !update.consolidation_promoted),
            ),
            (
                "route_authority_shadow_only",
                self.updates()
                    .all(|update| update.route_authority == "shadow_only"),
            ),
            (
                "fast_weights_session_local",
                self.updates().all(|update| {
                    matches!(update.scope.as_str(), "session" | "document" | "project")
                }),
            ),
            (
                "fast_weights_resettable",
                self.updates()
                    .all(|update| update.reset_handle.starts_with("reset:")),
            ),
            (
                "ttl_not_expired",
                self.updates().all(|update| update.age_ms < update.ttl_ms),
            ),
            (
                "drift_within_bound",
                self.updates()
                    .all(|update| update.observed_drift_bps <= update.drift_bound_bps),
            ),
            (
                "held_out_route_choice_improved",
                self.updates()
                    .all(|update| update.route_success_after_bps > update.route_success_before_bps),
            ),
            (
                "route_choice_regret_reduced",
                self.updates()
                    .all(|update| update.route_regret_after_bps < update.route_regret_before_bps),
            ),
            (
                "answer_packet_coverage_bound",
                metrics.answer_packet_coverage_bps >= MIN_ANSWER_PACKET_COVERAGE_BPS,
            ),
            (
                "compatibility_fence_bound",
                self.updates()
                    .all(|update| update.compatibility_fence == CURRENT_FENCE),
            ),
            (
                "privacy_classes_bound",
                self.updates()
                    .all(|update| valid_privacy_class(&update.privacy_class)),
            ),
            (
                "no_base_weight_mutation",
                self.updates().all(|update| !update.base_weight_mutated),
            ),
            (
                "no_live_policy_promotion",
                self.updates().all(|update| !update.live_policy_promoted),
            ),
            (
                "no_hidden_route_authority",
                self.updates().all(|update| !update.hidden_route_authority),
            ),
            (
                "no_hidden_chain",
                self.updates().all(|update| !update.hidden_chain_exposed),
            ),
            (
                "no_hidden_cloud",
                self.updates().all(|update| !update.hidden_cloud),
            ),
            (
                "no_runtime_bytes_loaded",
                self.updates()
                    .all(|update| update.runtime_bytes_loaded == 0),
            ),
            (
                "no_model_bytes_loaded",
                self.updates().all(|update| update.model_bytes_loaded == 0),
            ),
            (
                "verifier_regret_fast_weights_address_deterministic",
                address.starts_with("uas:verifier-regret-fast-weights:"),
            ),
            (
                "metadata_bound",
                metrics.max_delta_metadata_bytes <= MAX_DELTA_METADATA_BYTES,
            ),
            (
                "beats_static_policy_baseline",
                metrics.static_policy_baseline_bps < metrics.held_out_route_success_bps,
            ),
            (
                "beats_no_fast_weight_baseline",
                metrics.no_fast_weight_baseline_bps < metrics.held_out_route_success_bps,
            ),
            (
                "beats_stale_fast_weight_baseline",
                metrics.stale_fast_weight_baseline_bps < metrics.held_out_route_success_bps,
            ),
            (
                "beats_unbounded_delta_baseline",
                metrics.unbounded_delta_baseline_bps < metrics.held_out_route_success_bps,
            ),
        ]
    }

    fn updates(&self) -> impl Iterator<Item = &FastWeightUpdate> {
        self.fixtures.iter().flat_map(|fixture| &fixture.updates)
    }

    fn address(&self) -> String {
        let mut rows = Vec::with_capacity(self.fixtures.len());
        for fixture in &self.fixtures {
            let mut update_ids = fixture
                .updates
                .iter()
                .map(|update| update.update_id.as_str())
                .collect::<Vec<_>>();
            update_ids.sort_unstable();
            rows.push(format!(
                "{}:{}:{}:{}:{}",
                fixture.fixture_id,
                fixture.shadow_policy_ref,
                fixture.answer_packet_coverage_bps,
                fixture.no_fast_weight_baseline_bps,
                update_ids.join(",")
            ));
        }
        rows.sort_unstable();
        format!(
            "uas:verifier-regret-fast-weights:{}",
            sha256_hex(rows.join("|").as_bytes())
        )
    }
}

fn validate_fixtures(fixtures: &[FastWeightFixture]) -> Result<(), FastWeightError> {
    if fixtures.is_empty() {
        return Err(FastWeightError::MissingFixture);
    }
    let mut fixture_ids = BTreeSet::new();
    let mut update_ids = BTreeSet::new();
    let mut held_out_count = 0_u64;
    for fixture in fixtures {
        validate_fixture_header(fixture)?;
        if !fixture_ids.insert(fixture.fixture_id.as_str()) {
            return Err(FastWeightError::DuplicateFixture);
        }
        if fixture.updates.is_empty() {
            return Err(FastWeightError::MissingUpdate);
        }
        for update in &fixture.updates {
            validate_update(update)?;
            if !update_ids.insert(update.update_id.as_str()) {
                return Err(FastWeightError::DuplicateUpdate);
            }
            if update.split == "held_out" {
                held_out_count += 1;
            }
        }
        validate_baselines(fixture)?;
    }
    if held_out_count == 0 {
        return Err(FastWeightError::MissingHeldOutSplit);
    }
    Ok(())
}

fn validate_fixture_header(fixture: &FastWeightFixture) -> Result<(), FastWeightError> {
    if fixture.fixture_id.is_empty() {
        return Err(FastWeightError::MissingFixtureId);
    }
    if fixture.upstream_proof_pressure_ref.is_empty() {
        return Err(FastWeightError::MissingUpstreamProofPressure);
    }
    if fixture.shadow_policy_ref.is_empty() {
        return Err(FastWeightError::MissingShadowPolicy);
    }
    Ok(())
}

fn validate_baselines(fixture: &FastWeightFixture) -> Result<(), FastWeightError> {
    let min_success = fixture
        .updates
        .iter()
        .map(|update| update.route_success_after_bps)
        .min()
        .unwrap_or(0);
    if fixture.static_policy_baseline_bps >= min_success {
        return Err(FastWeightError::StaticPolicyBaselineUnbeaten);
    }
    if fixture.no_fast_weight_baseline_bps >= min_success {
        return Err(FastWeightError::NoFastWeightBaselineUnbeaten);
    }
    if fixture.stale_fast_weight_baseline_bps >= min_success {
        return Err(FastWeightError::StaleFastWeightBaselineUnbeaten);
    }
    if fixture.unbounded_delta_baseline_bps >= min_success {
        return Err(FastWeightError::UnboundedDeltaBaselineUnbeaten);
    }
    Ok(())
}

fn validate_update(update: &FastWeightUpdate) -> Result<(), FastWeightError> {
    if update.update_id.is_empty() {
        return Err(FastWeightError::MissingUpdateId);
    }
    if update.scope.is_empty() {
        return Err(FastWeightError::MissingScope);
    }
    if !valid_scope(&update.scope) {
        return Err(FastWeightError::InvalidScope);
    }
    if !valid_digest(&update.base_policy_digest) {
        return Err(FastWeightError::MissingBasePolicyDigest);
    }
    if !update.fast_weight_delta_ref.starts_with("delta:") {
        return Err(FastWeightError::MissingDeltaRef);
    }
    if !update.update_rule.starts_with("rule:") {
        return Err(FastWeightError::MissingUpdateRule);
    }
    if !update.verifier_regret_ref.starts_with("regret:") {
        return Err(FastWeightError::MissingVerifierRegret);
    }
    if !update.trace_surprise_ref.starts_with("trace:") {
        return Err(FastWeightError::MissingTraceSurprise);
    }
    if update.affected_policy_fields.is_empty() {
        return Err(FastWeightError::MissingPolicyField);
    }
    if !update
        .affected_policy_fields
        .iter()
        .all(|field| valid_policy_field(field))
    {
        return Err(FastWeightError::InvalidPolicyField);
    }
    if update.route_logit_delta_bps > MAX_ROUTE_LOGIT_DELTA_BPS {
        return Err(FastWeightError::RouteLogitDeltaOverflow);
    }
    if update.page_threshold_delta_bps > MAX_PAGE_THRESHOLD_DELTA_BPS {
        return Err(FastWeightError::PageThresholdDeltaOverflow);
    }
    if update.depth_threshold_delta_bps > MAX_DEPTH_THRESHOLD_DELTA_BPS {
        return Err(FastWeightError::DepthThresholdDeltaOverflow);
    }
    if update.verifier_prior_delta_bps > MAX_VERIFIER_PRIOR_DELTA_BPS {
        return Err(FastWeightError::VerifierPriorDeltaOverflow);
    }
    if update.tournament_temperature_delta_bps > MAX_TOURNAMENT_TEMPERATURE_DELTA_BPS {
        return Err(FastWeightError::TournamentTemperatureDeltaOverflow);
    }
    if update.drift_bound_bps == 0 {
        return Err(FastWeightError::MissingDriftBound);
    }
    if update.observed_drift_bps > update.drift_bound_bps
        || update.drift_bound_bps > DRIFT_BOUND_BPS
    {
        return Err(FastWeightError::DriftOverflow);
    }
    if update.ttl_ms == 0 {
        return Err(FastWeightError::MissingTtl);
    }
    if update.ttl_ms < MIN_FAST_WEIGHT_TTL_MS
        || update.ttl_ms > MAX_FAST_WEIGHT_TTL_MS
        || update.age_ms >= update.ttl_ms
    {
        return Err(FastWeightError::TtlExpired);
    }
    if !update.reset_handle.starts_with("reset:") {
        return Err(FastWeightError::MissingResetHandle);
    }
    if !update.rollback_handle.starts_with("rollback:") {
        return Err(FastWeightError::MissingRollback);
    }
    if !update.run_event_log_ref.starts_with("runlog:") {
        return Err(FastWeightError::MissingRunEventLog);
    }
    if !update.answer_packet_ref.starts_with("answer-packet:") {
        return Err(FastWeightError::MissingAnswerPacket);
    }
    if !update.held_out_result_ref.starts_with("heldout:") {
        return Err(FastWeightError::MissingHeldOutResult);
    }
    if !update
        .consolidation_candidate_ref
        .starts_with("consolidation-candidate:")
    {
        return Err(FastWeightError::MissingConsolidationCandidate);
    }
    if update.consolidation_promoted {
        return Err(FastWeightError::ConsolidationPromotion);
    }
    if update.base_weight_mutated {
        return Err(FastWeightError::BaseWeightMutation);
    }
    if update.live_policy_promoted {
        return Err(FastWeightError::LivePolicyPromotion);
    }
    if update.route_authority != "shadow_only" || update.hidden_route_authority {
        return Err(FastWeightError::HiddenRouteAuthority);
    }
    if update.hidden_chain_exposed {
        return Err(FastWeightError::HiddenChainExposure);
    }
    if update.hidden_cloud {
        return Err(FastWeightError::CloudSource);
    }
    if update.runtime_bytes_loaded > 0 {
        return Err(FastWeightError::RuntimeBytesLoaded);
    }
    if update.model_bytes_loaded > 0 {
        return Err(FastWeightError::ModelBytesLoaded);
    }
    if update.compatibility_fence != CURRENT_FENCE {
        return Err(FastWeightError::IncompatibleFence);
    }
    if !valid_privacy_class(&update.privacy_class) {
        return Err(FastWeightError::InvalidPrivacy);
    }
    if !valid_split(&update.split) {
        return Err(FastWeightError::InvalidSplit);
    }
    if update.route_success_after_bps <= update.route_success_before_bps {
        return Err(FastWeightError::NoFastWeightBaselineUnbeaten);
    }
    if update.route_regret_after_bps >= update.route_regret_before_bps {
        return Err(FastWeightError::StaticPolicyBaselineUnbeaten);
    }
    if update.delta_metadata_bytes > MAX_DELTA_METADATA_BYTES {
        return Err(FastWeightError::MetadataBudget);
    }
    Ok(())
}

fn valid_scope(scope: &str) -> bool {
    matches!(scope, "session" | "document" | "project")
}

fn valid_digest(value: &str) -> bool {
    value
        .strip_prefix("sha256:")
        .is_some_and(|tail| tail.len() == 64 && tail.chars().all(|c| c.is_ascii_hexdigit()))
}

fn valid_policy_field(field: &str) -> bool {
    matches!(
        field,
        "route_logits"
            | "page_threshold"
            | "depth_threshold"
            | "verifier_prior"
            | "tournament_temperature"
    )
}

fn valid_privacy_class(class: &str) -> bool {
    matches!(class, "local_private" | "vault_private" | "project_private")
}

fn valid_split(split: &str) -> bool {
    matches!(split, "train" | "held_out")
}

fn upstream_artifact_pass(path: &str) -> bool {
    std::fs::read_to_string(path)
        .ok()
        .and_then(|raw| serde_json::from_str::<serde_json::Value>(&raw).ok())
        .and_then(|value| value.get("overall_pass").and_then(|pass| pass.as_bool()))
        .unwrap_or(false)
}

fn invalid_fixture_axes(fixtures: &[FastWeightFixture]) -> Vec<(&'static str, bool)> {
    let mut cases: Vec<(&'static str, Box<dyn Fn(&mut FastWeightFixture)>)> = vec![
        (
            "duplicate_fixture_rejected",
            Box::new(|fixture| fixture.fixture_id = "fw_fixture_route_repair".to_string()),
        ),
        (
            "missing_fixture_id_rejected",
            Box::new(|fixture| fixture.fixture_id.clear()),
        ),
        (
            "missing_upstream_proof_pressure_rejected",
            Box::new(|fixture| fixture.upstream_proof_pressure_ref.clear()),
        ),
        (
            "missing_shadow_policy_rejected",
            Box::new(|fixture| fixture.shadow_policy_ref.clear()),
        ),
        (
            "missing_update_rejected",
            Box::new(|fixture| fixture.updates.clear()),
        ),
        (
            "duplicate_update_rejected",
            Box::new(|fixture| {
                if let Some(update) = fixture.updates.get_mut(0) {
                    update.update_id = "fw-update-proof-route-001".to_string();
                }
            }),
        ),
        (
            "missing_update_id_rejected",
            Box::new(|fixture| fixture.updates[0].update_id.clear()),
        ),
        (
            "missing_scope_rejected",
            Box::new(|fixture| fixture.updates[0].scope.clear()),
        ),
        (
            "invalid_scope_rejected",
            Box::new(|fixture| fixture.updates[0].scope = "global".to_string()),
        ),
        (
            "missing_base_policy_digest_rejected",
            Box::new(|fixture| fixture.updates[0].base_policy_digest.clear()),
        ),
        (
            "missing_delta_ref_rejected",
            Box::new(|fixture| fixture.updates[0].fast_weight_delta_ref.clear()),
        ),
        (
            "missing_update_rule_rejected",
            Box::new(|fixture| fixture.updates[0].update_rule.clear()),
        ),
        (
            "missing_verifier_regret_rejected",
            Box::new(|fixture| fixture.updates[0].verifier_regret_ref.clear()),
        ),
        (
            "missing_trace_surprise_rejected",
            Box::new(|fixture| fixture.updates[0].trace_surprise_ref.clear()),
        ),
        (
            "missing_affected_policy_field_rejected",
            Box::new(|fixture| fixture.updates[0].affected_policy_fields.clear()),
        ),
        (
            "invalid_policy_field_rejected",
            Box::new(|fixture| {
                fixture.updates[0].affected_policy_fields = vec!["base_weights".to_string()];
            }),
        ),
        (
            "route_logit_delta_overflow_rejected",
            Box::new(|fixture| fixture.updates[0].route_logit_delta_bps = 900),
        ),
        (
            "page_threshold_delta_overflow_rejected",
            Box::new(|fixture| fixture.updates[0].page_threshold_delta_bps = 900),
        ),
        (
            "depth_threshold_delta_overflow_rejected",
            Box::new(|fixture| fixture.updates[0].depth_threshold_delta_bps = 900),
        ),
        (
            "verifier_prior_delta_overflow_rejected",
            Box::new(|fixture| fixture.updates[0].verifier_prior_delta_bps = 900),
        ),
        (
            "tournament_temperature_delta_overflow_rejected",
            Box::new(|fixture| fixture.updates[0].tournament_temperature_delta_bps = 900),
        ),
        (
            "missing_drift_bound_rejected",
            Box::new(|fixture| fixture.updates[0].drift_bound_bps = 0),
        ),
        (
            "drift_overflow_rejected",
            Box::new(|fixture| fixture.updates[0].observed_drift_bps = 900),
        ),
        (
            "missing_ttl_rejected",
            Box::new(|fixture| fixture.updates[0].ttl_ms = 0),
        ),
        (
            "ttl_expired_rejected",
            Box::new(|fixture| {
                fixture.updates[0].age_ms = fixture.updates[0].ttl_ms;
            }),
        ),
        (
            "missing_reset_handle_rejected",
            Box::new(|fixture| fixture.updates[0].reset_handle.clear()),
        ),
        (
            "missing_rollback_rejected",
            Box::new(|fixture| fixture.updates[0].rollback_handle.clear()),
        ),
        (
            "missing_run_event_log_rejected",
            Box::new(|fixture| fixture.updates[0].run_event_log_ref.clear()),
        ),
        (
            "missing_answer_packet_rejected",
            Box::new(|fixture| fixture.updates[0].answer_packet_ref.clear()),
        ),
        (
            "missing_held_out_result_rejected",
            Box::new(|fixture| fixture.updates[0].held_out_result_ref.clear()),
        ),
        (
            "missing_consolidation_candidate_rejected",
            Box::new(|fixture| fixture.updates[0].consolidation_candidate_ref.clear()),
        ),
        (
            "invalid_split_rejected",
            Box::new(|fixture| fixture.updates[0].split = "validation".to_string()),
        ),
        (
            "consolidation_promotion_rejected",
            Box::new(|fixture| fixture.updates[0].consolidation_promoted = true),
        ),
        (
            "base_weight_mutation_rejected",
            Box::new(|fixture| fixture.updates[0].base_weight_mutated = true),
        ),
        (
            "live_policy_promotion_rejected",
            Box::new(|fixture| fixture.updates[0].live_policy_promoted = true),
        ),
        (
            "hidden_route_authority_rejected",
            Box::new(|fixture| fixture.updates[0].hidden_route_authority = true),
        ),
        (
            "hidden_chain_exposure_rejected",
            Box::new(|fixture| fixture.updates[0].hidden_chain_exposed = true),
        ),
        (
            "cloud_source_rejected",
            Box::new(|fixture| fixture.updates[0].hidden_cloud = true),
        ),
        (
            "runtime_bytes_rejected",
            Box::new(|fixture| fixture.updates[0].runtime_bytes_loaded = 1),
        ),
        (
            "model_bytes_rejected",
            Box::new(|fixture| fixture.updates[0].model_bytes_loaded = 1),
        ),
        (
            "incompatible_fence_rejected",
            Box::new(|fixture| fixture.updates[0].compatibility_fence = "fence:old".to_string()),
        ),
        (
            "invalid_privacy_rejected",
            Box::new(|fixture| fixture.updates[0].privacy_class = "public".to_string()),
        ),
        (
            "static_policy_unbeaten_rejected",
            Box::new(|fixture| fixture.static_policy_baseline_bps = 9800),
        ),
        (
            "no_fast_weight_unbeaten_rejected",
            Box::new(|fixture| fixture.no_fast_weight_baseline_bps = 9800),
        ),
        (
            "stale_fast_weight_unbeaten_rejected",
            Box::new(|fixture| fixture.stale_fast_weight_baseline_bps = 9800),
        ),
        (
            "unbounded_delta_unbeaten_rejected",
            Box::new(|fixture| fixture.unbounded_delta_baseline_bps = 9800),
        ),
        (
            "metadata_budget_rejected",
            Box::new(|fixture| {
                fixture.updates[0].delta_metadata_bytes = MAX_DELTA_METADATA_BYTES + 1
            }),
        ),
    ];

    let mut axes = Vec::with_capacity(cases.len());
    for (axis, mutate) in cases.drain(..) {
        let mut candidate = fixtures.to_vec();
        if candidate.len() < 2 || candidate[1].updates.is_empty() {
            axes.push((axis, false));
            continue;
        }
        mutate(&mut candidate[1]);
        axes.push((axis, FastWeightRegistry::new(candidate).is_err()));
    }
    let mut missing_held_out = fixtures.to_vec();
    for fixture in &mut missing_held_out {
        for update in &mut fixture.updates {
            update.split = "train".to_string();
        }
    }
    axes.push((
        "missing_held_out_split_rejected",
        FastWeightRegistry::new(missing_held_out).is_err(),
    ));
    axes
}

fn fixture_fast_weights() -> Vec<FastWeightFixture> {
    vec![
        FastWeightFixture {
            fixture_id: "fw_fixture_route_repair".to_string(),
            upstream_proof_pressure_ref: "artifact:proof_pressure_signal:result".to_string(),
            shadow_policy_ref: "policy:route-scout-shadow:v4".to_string(),
            answer_packet_coverage_bps: 10_000,
            static_policy_baseline_bps: 7_600,
            no_fast_weight_baseline_bps: 8_200,
            stale_fast_weight_baseline_bps: 7_700,
            unbounded_delta_baseline_bps: 7_100,
            updates: vec![
                update(
                    "fw-update-proof-route-001",
                    "session",
                    &["route_logits", "verifier_prior"],
                    260,
                    40,
                    0,
                    320,
                    0,
                    410,
                    30_000,
                    6_000,
                    "train",
                    8_300,
                    9_200,
                    2_400,
                    1_100,
                ),
                update(
                    "fw-update-proof-route-002",
                    "document",
                    &["page_threshold", "route_logits"],
                    180,
                    360,
                    0,
                    210,
                    0,
                    380,
                    45_000,
                    8_000,
                    "train",
                    8_400,
                    9_250,
                    2_200,
                    900,
                ),
                update(
                    "fw-update-proof-route-003",
                    "project",
                    &["depth_threshold", "verifier_prior"],
                    120,
                    0,
                    290,
                    300,
                    0,
                    460,
                    60_000,
                    12_000,
                    "held_out",
                    8_500,
                    9_150,
                    2_100,
                    950,
                ),
                update(
                    "fw-update-proof-route-004",
                    "session",
                    &["tournament_temperature", "route_logits"],
                    210,
                    0,
                    0,
                    240,
                    260,
                    430,
                    24_000,
                    4_000,
                    "held_out",
                    8_450,
                    9_100,
                    2_000,
                    880,
                ),
                update(
                    "fw-update-proof-route-005",
                    "document",
                    &["page_threshold", "depth_threshold"],
                    90,
                    310,
                    220,
                    120,
                    0,
                    390,
                    36_000,
                    7_000,
                    "held_out",
                    8_600,
                    9_200,
                    2_050,
                    900,
                ),
            ],
        },
        FastWeightFixture {
            fixture_id: "fw_fixture_cold_kv_route".to_string(),
            upstream_proof_pressure_ref: "artifact:proof_pressure_signal:result".to_string(),
            shadow_policy_ref: "policy:route-scout-shadow:v4".to_string(),
            answer_packet_coverage_bps: 10_000,
            static_policy_baseline_bps: 7_500,
            no_fast_weight_baseline_bps: 8_100,
            stale_fast_weight_baseline_bps: 7_600,
            unbounded_delta_baseline_bps: 6_900,
            updates: vec![
                update(
                    "fw-update-kv-route-001",
                    "session",
                    &["route_logits", "page_threshold"],
                    240,
                    420,
                    0,
                    160,
                    0,
                    440,
                    20_000,
                    3_000,
                    "train",
                    8_350,
                    9_300,
                    2_300,
                    1_000,
                ),
                update(
                    "fw-update-kv-route-002",
                    "document",
                    &["depth_threshold", "page_threshold"],
                    140,
                    390,
                    260,
                    130,
                    0,
                    470,
                    40_000,
                    9_000,
                    "train",
                    8_500,
                    9_250,
                    2_150,
                    970,
                ),
                update(
                    "fw-update-kv-route-003",
                    "project",
                    &["verifier_prior", "route_logits"],
                    290,
                    0,
                    0,
                    420,
                    0,
                    520,
                    75_000,
                    15_000,
                    "held_out",
                    8_550,
                    9_180,
                    2_200,
                    940,
                ),
                update(
                    "fw-update-kv-route-004",
                    "session",
                    &["tournament_temperature", "verifier_prior"],
                    130,
                    0,
                    0,
                    350,
                    310,
                    450,
                    18_000,
                    2_000,
                    "held_out",
                    8_300,
                    9_050,
                    2_000,
                    900,
                ),
                update(
                    "fw-update-kv-route-005",
                    "document",
                    &["route_logits", "page_threshold", "depth_threshold"],
                    300,
                    410,
                    260,
                    230,
                    0,
                    500,
                    50_000,
                    10_000,
                    "held_out",
                    8_650,
                    9_220,
                    2_120,
                    850,
                ),
            ],
        },
    ]
}

#[allow(clippy::too_many_arguments)]
fn update(
    id: &str,
    scope: &str,
    fields: &[&str],
    route_logit_delta_bps: u64,
    page_threshold_delta_bps: u64,
    depth_threshold_delta_bps: u64,
    verifier_prior_delta_bps: u64,
    tournament_temperature_delta_bps: u64,
    observed_drift_bps: u64,
    ttl_ms: u64,
    age_ms: u64,
    split: &str,
    route_success_before_bps: u64,
    route_success_after_bps: u64,
    route_regret_before_bps: u64,
    route_regret_after_bps: u64,
) -> FastWeightUpdate {
    FastWeightUpdate {
        update_id: id.to_string(),
        scope: scope.to_string(),
        base_policy_digest:
            "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef".to_string(),
        fast_weight_delta_ref: format!("delta:{id}"),
        update_rule: "rule:verifier-regret-surprise-bounded-v1".to_string(),
        verifier_regret_ref: format!("regret:{id}"),
        trace_surprise_ref: format!("trace:{id}"),
        affected_policy_fields: fields.iter().map(|field| (*field).to_string()).collect(),
        route_logit_delta_bps,
        page_threshold_delta_bps,
        depth_threshold_delta_bps,
        verifier_prior_delta_bps,
        tournament_temperature_delta_bps,
        drift_bound_bps: DRIFT_BOUND_BPS,
        observed_drift_bps,
        ttl_ms,
        age_ms,
        reset_handle: format!("reset:{id}"),
        rollback_handle: format!("rollback:{id}"),
        run_event_log_ref: format!("runlog:{id}"),
        answer_packet_ref: format!("answer-packet:{id}"),
        held_out_result_ref: format!("heldout:{id}"),
        consolidation_candidate_ref: format!("consolidation-candidate:{id}"),
        route_success_before_bps,
        route_success_after_bps,
        route_regret_before_bps,
        route_regret_after_bps,
        compatibility_fence: CURRENT_FENCE.to_string(),
        privacy_class: match scope {
            "project" => "project_private",
            "document" => "vault_private",
            _ => "local_private",
        }
        .to_string(),
        split: split.to_string(),
        delta_metadata_bytes: 96 * 1024,
        route_authority: "shadow_only".to_string(),
        base_weight_mutated: false,
        live_policy_promoted: false,
        consolidation_promoted: false,
        hidden_route_authority: false,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        runtime_bytes_loaded: 0,
        model_bytes_loaded: 0,
    }
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
            operator: ">=".to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual >= expected);
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
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual <= expected);
}

fn add_u64_lt_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    ceiling: u64,
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
            operator: "<".to_string(),
            value: serde_json::Value::from(ceiling),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual < ceiling);
}

fn add_label_axis(
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
            unit: "id".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String("uas:".to_string()),
            unit: "id".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual.starts_with("uas:"));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_fixture_rejects() {
        let error = match FastWeightRegistry::new(Vec::new()) {
            Ok(_) => panic!("empty fixture unexpectedly passed"),
            Err(error) => error,
        };
        assert_eq!(error, FastWeightError::MissingFixture);
    }

    #[test]
    fn invalid_fixture_cases_reject() {
        let fixtures = fixture_fast_weights();
        for (axis, passed) in invalid_fixture_axes(&fixtures) {
            assert!(passed, "{axis} did not reject");
        }
    }

    #[test]
    fn fast_weight_address_is_order_stable() {
        let fixtures = fixture_fast_weights();
        let registry = FastWeightRegistry::new(fixtures.clone()).unwrap();
        let address = registry.address();
        assert!(address.starts_with("uas:verifier-regret-fast-weights:sha256:"));
        let reversed = fixtures.into_iter().rev().collect();
        let reversed_registry = FastWeightRegistry::new(reversed).unwrap();
        assert_eq!(address, reversed_registry.address());
    }

    #[test]
    fn artifact_contains_required_axes() {
        let artifact = build_artifact().unwrap();
        for axis in REQUIRED_AXES {
            assert!(
                artifact.measurements.contains_key(*axis),
                "missing measurement axis {axis}"
            );
            assert!(
                artifact.acceptance_thresholds.contains_key(*axis),
                "missing threshold axis {axis}"
            );
            assert!(
                artifact.pass_per_axis.contains_key(*axis),
                "missing pass axis {axis}"
            );
        }
    }
}
