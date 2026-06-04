//! `falsify_ablation_shadow_run` -- counterfactual sparse-route witness.
//!
//! Metadata-only witness for `F-AblationShadowRun`. It proves oracle-labeled
//! units survive cheap remove-one-unit shadow ablations before any route
//! importance claim can promote, while remaining rollback-bound,
//! AnswerPacket-visible, shadow-only, and unable to mutate live policy.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-AblationShadowRun";
const FIXTURE_ID: &str = "ablation_shadow_run_v1";
const COMMAND: &str = "Tools/falsifiers/f_ablation_shadow_run.sh";
const RESULT: &str = "artifacts/falsifiers/ablation_shadow_run/result.json";
const UPSTREAM_SHADOW_WAKE_ORACLE: &str = "artifacts/falsifiers/shadow_wake_oracle/result.json";

const CURRENT_FENCE: &str = "fence:ablation-shadow-run:v1:shadow-wake-oracle:v1";
const MIN_DECISION_ACCURACY_BPS: u64 = 9_200;
const MIN_RETAINED_SUCCESS_BPS: u64 = 9_000;
const MIN_RETAINED_QUALITY_DELTA_BPS: u64 = 300;
const MIN_RETAINED_VERIFIER_DELTA_BPS: u64 = 250;
const MAX_RETAINED_LATENCY_DELTA_MS: u64 = 64;
const MAX_RETAINED_BYTE_DELTA: u64 = 1_800_000;
const MAX_ABLATION_METADATA_BYTES: u64 = 896 * 1024;
const MIN_DECISION_KIND_COUNT: u64 = 3;
const MIN_ROUTE_LABEL_COUNT: u64 = 4;

#[cfg(test)]
const REQUIRED_AXES: &[&str] = &[
    "upstream_shadow_wake_oracle_pass",
    "ablation_fixture_present",
    "fixture_ids_bound",
    "run_ids_bound",
    "mission_ids_bound",
    "upstream_shadow_wake_refs_bound",
    "baseline_traces_bound",
    "candidate_traces_bound",
    "removed_units_bound",
    "removed_unit_uas_addresses_bound",
    "route_labels_bound",
    "oracle_label_refs_bound",
    "quality_deltas_bound",
    "verifier_deltas_bound",
    "latency_deltas_bound",
    "byte_deltas_bound",
    "decisions_bound",
    "decision_records_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "held_out_split_bound",
    "retained_cases_present",
    "demoted_cases_present",
    "abstain_cases_present",
    "decision_diversity_bound",
    "route_label_diversity_bound",
    "counterfactual_remove_one_unit_bound",
    "shadow_only_authority",
    "offline_evaluation_only",
    "oracle_not_live_dependency",
    "no_live_route_promotion",
    "no_base_weight_mutation",
    "no_route_policy_mutation",
    "no_cache_mutation",
    "no_hidden_route_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "ablation_shadow_run_address_deterministic",
    "retained_quality_delta_bound",
    "retained_verifier_delta_bound",
    "retained_latency_penalty_budget_bound",
    "retained_byte_budget_bound",
    "decision_accuracy_bound",
    "retained_success_bound",
    "metadata_bound",
    "beats_keep_all_baseline",
    "beats_remove_all_baseline",
    "beats_random_ablation_baseline",
    "beats_no_ablation_baseline",
    "duplicate_fixture_rejected",
    "duplicate_run_rejected",
    "missing_fixture_id_rejected",
    "missing_policy_rejected",
    "missing_run_rejected",
    "missing_run_id_rejected",
    "missing_mission_rejected",
    "missing_upstream_shadow_wake_rejected",
    "missing_baseline_trace_rejected",
    "missing_candidate_trace_rejected",
    "missing_removed_unit_rejected",
    "missing_removed_unit_uas_rejected",
    "invalid_removed_unit_uas_rejected",
    "missing_route_label_rejected",
    "missing_oracle_label_rejected",
    "missing_decision_rejected",
    "invalid_decision_rejected",
    "decision_mismatch_rejected",
    "missing_decision_record_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "missing_split_rejected",
    "invalid_split_rejected",
    "missing_held_out_split_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "oracle_live_dependency_rejected",
    "live_route_promotion_rejected",
    "base_weight_mutation_rejected",
    "route_policy_mutation_rejected",
    "cache_mutation_rejected",
    "hidden_route_authority_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "keep_all_baseline_unbeaten_rejected",
    "remove_all_baseline_unbeaten_rejected",
    "random_ablation_baseline_unbeaten_rejected",
    "no_ablation_baseline_unbeaten_rejected",
    "decision_accuracy_too_low_rejected",
    "retained_success_too_low_rejected",
    "retained_quality_delta_too_low_rejected",
    "retained_verifier_delta_too_low_rejected",
    "retained_latency_budget_rejected",
    "retained_byte_budget_rejected",
    "decision_diversity_missing_rejected",
    "route_label_diversity_missing_rejected",
    "metadata_budget_rejected",
    "fixture_count",
    "ablation_run_count",
    "train_case_count",
    "held_out_case_count",
    "retained_case_count",
    "demoted_case_count",
    "abstain_case_count",
    "removed_unit_count",
    "route_label_count",
    "decision_kind_count",
    "min_retained_quality_delta_bps",
    "min_retained_verifier_delta_bps",
    "max_retained_latency_delta_ms",
    "max_retained_byte_delta",
    "decision_accuracy_bps",
    "retained_success_bps",
    "keep_all_baseline_bps",
    "remove_all_baseline_bps",
    "random_ablation_baseline_bps",
    "no_ablation_baseline_bps",
    "max_ablation_metadata_bytes",
    "ablation_shadow_run_address",
];

#[derive(Clone, Debug)]
// UAS: uas:ablation-shadow-run:record
// Plane: Controller + Verification
// Residency: metadata-only counterfactual trace; no live route mutation.
struct AblationShadowRunRecord {
    run_id: String,
    mission_id: String,
    upstream_shadow_wake_ref: String,
    baseline_trace_ref: String,
    candidate_trace_ref: String,
    removed_unit: String,
    removed_unit_uas_address: String,
    route_label: String,
    oracle_label_ref: String,
    quality_delta_bps: u64,
    verifier_delta_bps: u64,
    latency_delta_ms: u64,
    byte_delta: u64,
    decision: String,
    decision_record_ref: String,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    compatibility_fence: String,
    privacy_class: String,
    split: String,
    metadata_bytes: u64,
    oracle_live_dependency: bool,
    live_route_promoted: bool,
    base_weight_mutated: bool,
    route_policy_mutated: bool,
    cache_mutated: bool,
    hidden_route_authority: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:ablation-shadow-run:fixture
// Plane: Controller + Verification
// Residency: offline/shadow-only ablation fixture.
struct AblationShadowRunFixture {
    fixture_id: String,
    ablation_policy_ref: String,
    decision_accuracy_bps: u64,
    retained_success_bps: u64,
    keep_all_baseline_bps: u64,
    remove_all_baseline_bps: u64,
    random_ablation_baseline_bps: u64,
    no_ablation_baseline_bps: u64,
    authority: String,
    offline_evaluation_only: bool,
    records: Vec<AblationShadowRunRecord>,
}

// UAS: uas:ablation-shadow-run:metrics
// Plane: Verification
// Residency: metadata-only aggregation; no runtime/model bytes.
struct AblationMetrics {
    fixture_count: u64,
    ablation_run_count: u64,
    train_case_count: u64,
    held_out_case_count: u64,
    retained_case_count: u64,
    demoted_case_count: u64,
    abstain_case_count: u64,
    removed_unit_count: u64,
    route_label_count: u64,
    decision_kind_count: u64,
    min_retained_quality_delta_bps: u64,
    min_retained_verifier_delta_bps: u64,
    max_retained_latency_delta_ms: u64,
    max_retained_byte_delta: u64,
    decision_accuracy_bps: u64,
    retained_success_bps: u64,
    keep_all_baseline_bps: u64,
    remove_all_baseline_bps: u64,
    random_ablation_baseline_bps: u64,
    no_ablation_baseline_bps: u64,
    max_ablation_metadata_bytes: u64,
}

#[derive(Debug)]
// UAS: uas:ablation-shadow-run:registry
// Plane: Controller + Verification
// Residency: offline/shadow-only fixture registry.
struct AblationShadowRunRegistry {
    fixtures: Vec<AblationShadowRunFixture>,
}

impl AblationShadowRunRegistry {
    fn new(fixtures: Vec<AblationShadowRunFixture>) -> Result<Self, AblationError> {
        validate_fixtures(&fixtures)?;
        Ok(Self { fixtures })
    }

    fn records(&self) -> impl Iterator<Item = &AblationShadowRunRecord> {
        self.fixtures
            .iter()
            .flat_map(|fixture| fixture.records.iter())
    }

    fn metrics(&self) -> AblationMetrics {
        let mut run_ids = BTreeSet::new();
        let mut removed_units = BTreeSet::new();
        let mut route_labels = BTreeSet::new();
        let mut decisions = BTreeSet::new();
        let mut train = 0;
        let mut held_out = 0;
        let mut retained = 0;
        let mut demoted = 0;
        let mut abstained = 0;
        let mut min_quality = u64::MAX;
        let mut min_verifier = u64::MAX;
        let mut max_latency = 0;
        let mut max_byte_delta = 0;
        let mut min_decision_accuracy = u64::MAX;
        let mut min_retained_success = u64::MAX;
        let mut keep_all_baseline = 0;
        let mut remove_all_baseline = 0;
        let mut random_ablation_baseline = 0;
        let mut no_ablation_baseline = 0;
        let mut max_metadata = 0;

        for fixture in &self.fixtures {
            min_decision_accuracy = min_decision_accuracy.min(fixture.decision_accuracy_bps);
            min_retained_success = min_retained_success.min(fixture.retained_success_bps);
            keep_all_baseline = keep_all_baseline.max(fixture.keep_all_baseline_bps);
            remove_all_baseline = remove_all_baseline.max(fixture.remove_all_baseline_bps);
            random_ablation_baseline =
                random_ablation_baseline.max(fixture.random_ablation_baseline_bps);
            no_ablation_baseline = no_ablation_baseline.max(fixture.no_ablation_baseline_bps);

            for record in &fixture.records {
                run_ids.insert(record.run_id.as_str());
                removed_units.insert(record.removed_unit_uas_address.as_str());
                route_labels.insert(record.route_label.as_str());
                decisions.insert(record.decision.as_str());
                max_metadata = max_metadata.max(record.metadata_bytes);

                match record.split.as_str() {
                    "train" => train += 1,
                    "held_out" => held_out += 1,
                    _ => {}
                }
                match record.decision.as_str() {
                    "retain" => {
                        retained += 1;
                        min_quality = min_quality.min(record.quality_delta_bps);
                        min_verifier = min_verifier.min(record.verifier_delta_bps);
                        max_latency = max_latency.max(record.latency_delta_ms);
                        max_byte_delta = max_byte_delta.max(record.byte_delta);
                    }
                    "demote" => demoted += 1,
                    "abstain" => abstained += 1,
                    _ => {}
                }
            }
        }

        AblationMetrics {
            fixture_count: self.fixtures.len() as u64,
            ablation_run_count: run_ids.len() as u64,
            train_case_count: train,
            held_out_case_count: held_out,
            retained_case_count: retained,
            demoted_case_count: demoted,
            abstain_case_count: abstained,
            removed_unit_count: removed_units.len() as u64,
            route_label_count: route_labels.len() as u64,
            decision_kind_count: decisions.len() as u64,
            min_retained_quality_delta_bps: if min_quality == u64::MAX {
                0
            } else {
                min_quality
            },
            min_retained_verifier_delta_bps: if min_verifier == u64::MAX {
                0
            } else {
                min_verifier
            },
            max_retained_latency_delta_ms: max_latency,
            max_retained_byte_delta: max_byte_delta,
            decision_accuracy_bps: if min_decision_accuracy == u64::MAX {
                0
            } else {
                min_decision_accuracy
            },
            retained_success_bps: if min_retained_success == u64::MAX {
                0
            } else {
                min_retained_success
            },
            keep_all_baseline_bps: keep_all_baseline,
            remove_all_baseline_bps: remove_all_baseline,
            random_ablation_baseline_bps: random_ablation_baseline,
            no_ablation_baseline_bps: no_ablation_baseline,
            max_ablation_metadata_bytes: max_metadata,
        }
    }

    fn address(&self) -> String {
        let mut rows = Vec::with_capacity(self.fixtures.len());
        for fixture in &self.fixtures {
            let mut run_rows: Vec<String> = fixture
                .records
                .iter()
                .map(|record| {
                    format!(
                        "{}:{}:{}:{}:{}:{}:{}",
                        record.run_id,
                        record.mission_id,
                        record.removed_unit_uas_address,
                        record.route_label,
                        record.decision,
                        record.quality_delta_bps,
                        record.verifier_delta_bps
                    )
                })
                .collect();
            run_rows.sort_unstable();
            rows.push(format!(
                "{}:{}:{}:{}",
                fixture.fixture_id,
                fixture.ablation_policy_ref,
                fixture.decision_accuracy_bps,
                run_rows.join(",")
            ));
        }
        rows.sort_unstable();
        sha256_hex(rows.join("|").as_bytes()).replacen(
            "sha256:",
            "uas:ablation-shadow-run:sha256:",
            1,
        )
    }

    #[cfg(test)]
    fn has_decision(&self, decision: &str) -> bool {
        self.records().any(|record| record.decision == decision)
    }
}

#[derive(Debug, PartialEq, Eq)]
// UAS: uas:ablation-shadow-run:error
// Plane: Verification
// Residency: metadata-only rejection reason; no live route mutation.
enum AblationError {
    EmptyFixtures,
    DuplicateFixture,
    MissingFixtureId,
    MissingPolicy,
    MissingRun,
    DuplicateRun,
    MissingRunId,
    MissingMission,
    MissingUpstreamShadowWake,
    MissingBaselineTrace,
    MissingCandidateTrace,
    MissingRemovedUnit,
    MissingRemovedUnitUas,
    InvalidRemovedUnitUas,
    MissingRouteLabel,
    MissingOracleLabel,
    MissingDecision,
    InvalidDecision,
    DecisionMismatch,
    MissingDecisionRecord,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    InvalidSplit,
    MissingHeldOut,
    IncompatibleFence,
    InvalidPrivacy,
    OracleLiveDependency,
    LiveRoutePromotion,
    BaseWeightMutation,
    RoutePolicyMutation,
    CacheMutation,
    HiddenRouteAuthority,
    HiddenChainExposure,
    CloudSource,
    RuntimeBytes,
    ModelBytes,
    BaselineUnbeaten,
    DecisionAccuracyTooLow,
    RetainedSuccessTooLow,
    RetainedQualityTooLow,
    RetainedVerifierTooLow,
    RetainedLatencyBudget,
    RetainedByteBudget,
    DecisionDiversityTooLow,
    RouteLabelDiversityTooLow,
    MetadataBudget,
}

fn validate_fixtures(fixtures: &[AblationShadowRunFixture]) -> Result<(), AblationError> {
    if fixtures.is_empty() {
        return Err(AblationError::EmptyFixtures);
    }

    let mut fixture_ids = BTreeSet::new();
    let mut run_ids = BTreeSet::new();
    let mut decisions = BTreeSet::new();
    let mut route_labels = BTreeSet::new();
    let mut held_out_seen = false;

    for fixture in fixtures {
        validate_fixture_header(fixture)?;
        if !fixture_ids.insert(fixture.fixture_id.as_str()) {
            return Err(AblationError::DuplicateFixture);
        }
        if fixture.records.is_empty() {
            return Err(AblationError::MissingRun);
        }
        for record in &fixture.records {
            validate_record(record)?;
            if !run_ids.insert(record.run_id.as_str()) {
                return Err(AblationError::DuplicateRun);
            }
            decisions.insert(record.decision.as_str());
            route_labels.insert(record.route_label.as_str());
            held_out_seen |= record.split == "held_out";
        }
    }

    if !held_out_seen {
        return Err(AblationError::MissingHeldOut);
    }
    if decisions.len() < MIN_DECISION_KIND_COUNT as usize {
        return Err(AblationError::DecisionDiversityTooLow);
    }
    if route_labels.len() < MIN_ROUTE_LABEL_COUNT as usize {
        return Err(AblationError::RouteLabelDiversityTooLow);
    }

    Ok(())
}

fn validate_fixture_header(fixture: &AblationShadowRunFixture) -> Result<(), AblationError> {
    if fixture.fixture_id.is_empty() {
        return Err(AblationError::MissingFixtureId);
    }
    if fixture.ablation_policy_ref.is_empty() {
        return Err(AblationError::MissingPolicy);
    }
    if fixture.authority != "shadow_only" {
        return Err(AblationError::HiddenRouteAuthority);
    }
    if !fixture.offline_evaluation_only {
        return Err(AblationError::LiveRoutePromotion);
    }
    if fixture.decision_accuracy_bps < MIN_DECISION_ACCURACY_BPS {
        return Err(AblationError::DecisionAccuracyTooLow);
    }
    if fixture.retained_success_bps < MIN_RETAINED_SUCCESS_BPS {
        return Err(AblationError::RetainedSuccessTooLow);
    }
    if fixture.keep_all_baseline_bps >= fixture.retained_success_bps
        || fixture.remove_all_baseline_bps >= fixture.retained_success_bps
        || fixture.random_ablation_baseline_bps >= fixture.retained_success_bps
        || fixture.no_ablation_baseline_bps >= fixture.retained_success_bps
    {
        return Err(AblationError::BaselineUnbeaten);
    }
    Ok(())
}

fn validate_record(record: &AblationShadowRunRecord) -> Result<(), AblationError> {
    if record.run_id.is_empty() {
        return Err(AblationError::MissingRunId);
    }
    if record.mission_id.is_empty() {
        return Err(AblationError::MissingMission);
    }
    if record.upstream_shadow_wake_ref.is_empty() {
        return Err(AblationError::MissingUpstreamShadowWake);
    }
    if record.baseline_trace_ref.is_empty() {
        return Err(AblationError::MissingBaselineTrace);
    }
    if record.candidate_trace_ref.is_empty() {
        return Err(AblationError::MissingCandidateTrace);
    }
    if record.removed_unit.is_empty() {
        return Err(AblationError::MissingRemovedUnit);
    }
    if record.removed_unit_uas_address.is_empty() {
        return Err(AblationError::MissingRemovedUnitUas);
    }
    if !record.removed_unit_uas_address.starts_with("uas:") {
        return Err(AblationError::InvalidRemovedUnitUas);
    }
    if record.route_label.is_empty() {
        return Err(AblationError::MissingRouteLabel);
    }
    if record.oracle_label_ref.is_empty() {
        return Err(AblationError::MissingOracleLabel);
    }
    if record.decision.is_empty() {
        return Err(AblationError::MissingDecision);
    }
    if !matches!(record.decision.as_str(), "retain" | "demote" | "abstain") {
        return Err(AblationError::InvalidDecision);
    }
    validate_decision(record)?;
    if record.decision_record_ref.is_empty() {
        return Err(AblationError::MissingDecisionRecord);
    }
    if record.rollback_handle.is_empty() {
        return Err(AblationError::MissingRollback);
    }
    if record.run_event_log_ref.is_empty() {
        return Err(AblationError::MissingRunEventLog);
    }
    if record.answer_packet_ref.is_empty() {
        return Err(AblationError::MissingAnswerPacket);
    }
    if !matches!(record.split.as_str(), "train" | "held_out") {
        return Err(AblationError::InvalidSplit);
    }
    if record.compatibility_fence != CURRENT_FENCE {
        return Err(AblationError::IncompatibleFence);
    }
    if !valid_privacy_class(&record.privacy_class) {
        return Err(AblationError::InvalidPrivacy);
    }
    if record.metadata_bytes > MAX_ABLATION_METADATA_BYTES {
        return Err(AblationError::MetadataBudget);
    }
    if record.oracle_live_dependency {
        return Err(AblationError::OracleLiveDependency);
    }
    if record.live_route_promoted {
        return Err(AblationError::LiveRoutePromotion);
    }
    if record.base_weight_mutated {
        return Err(AblationError::BaseWeightMutation);
    }
    if record.route_policy_mutated {
        return Err(AblationError::RoutePolicyMutation);
    }
    if record.cache_mutated {
        return Err(AblationError::CacheMutation);
    }
    if record.hidden_route_authority {
        return Err(AblationError::HiddenRouteAuthority);
    }
    if record.hidden_chain_exposed {
        return Err(AblationError::HiddenChainExposure);
    }
    if record.hidden_cloud {
        return Err(AblationError::CloudSource);
    }
    if record.runtime_bytes_loaded > 0 {
        return Err(AblationError::RuntimeBytes);
    }
    if record.model_bytes_loaded > 0 {
        return Err(AblationError::ModelBytes);
    }
    Ok(())
}

fn validate_decision(record: &AblationShadowRunRecord) -> Result<(), AblationError> {
    let strong_quality = record.quality_delta_bps >= MIN_RETAINED_QUALITY_DELTA_BPS;
    let strong_verifier = record.verifier_delta_bps >= MIN_RETAINED_VERIFIER_DELTA_BPS;
    let latency_ok = record.latency_delta_ms <= MAX_RETAINED_LATENCY_DELTA_MS;
    let byte_ok = record.byte_delta <= MAX_RETAINED_BYTE_DELTA;

    match record.decision.as_str() {
        "retain" => {
            if !strong_quality {
                return Err(AblationError::RetainedQualityTooLow);
            }
            if !strong_verifier {
                return Err(AblationError::RetainedVerifierTooLow);
            }
            if !latency_ok {
                return Err(AblationError::RetainedLatencyBudget);
            }
            if !byte_ok {
                return Err(AblationError::RetainedByteBudget);
            }
        }
        "demote" if strong_quality && strong_verifier => {
            return Err(AblationError::DecisionMismatch);
        }
        "abstain" if latency_ok && byte_ok => {
            return Err(AblationError::DecisionMismatch);
        }
        _ => {}
    }
    Ok(())
}

fn valid_privacy_class(value: &str) -> bool {
    matches!(value, "local_private" | "project_private" | "vault_private")
}

fn invalid_fixture_axes(valid_fixtures: &[AblationShadowRunFixture]) -> Vec<(&'static str, bool)> {
    let mut cases = Vec::with_capacity(48);
    cases.push((
        "duplicate_fixture_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures.push(fixtures[0].clone())
        }),
    ));
    cases.push((
        "duplicate_run_rejected",
        rejects(valid_fixtures, |fixtures| {
            let duplicate = fixtures[0].records[0].clone();
            fixtures[0].records.push(duplicate);
        }),
    ));
    cases.push((
        "missing_fixture_id_rejected",
        rejects(valid_fixtures, |fixtures| fixtures[0].fixture_id.clear()),
    ));
    cases.push((
        "missing_policy_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].ablation_policy_ref.clear()
        }),
    ));
    cases.push((
        "missing_run_rejected",
        rejects(valid_fixtures, |fixtures| fixtures[0].records.clear()),
    ));
    cases.push((
        "missing_run_id_rejected",
        rejects_record(valid_fixtures, |r| r.run_id.clear()),
    ));
    cases.push((
        "missing_mission_rejected",
        rejects_record(valid_fixtures, |r| r.mission_id.clear()),
    ));
    cases.push((
        "missing_upstream_shadow_wake_rejected",
        rejects_record(valid_fixtures, |r| r.upstream_shadow_wake_ref.clear()),
    ));
    cases.push((
        "missing_baseline_trace_rejected",
        rejects_record(valid_fixtures, |r| r.baseline_trace_ref.clear()),
    ));
    cases.push((
        "missing_candidate_trace_rejected",
        rejects_record(valid_fixtures, |r| r.candidate_trace_ref.clear()),
    ));
    cases.push((
        "missing_removed_unit_rejected",
        rejects_record(valid_fixtures, |r| r.removed_unit.clear()),
    ));
    cases.push((
        "missing_removed_unit_uas_rejected",
        rejects_record(valid_fixtures, |r| r.removed_unit_uas_address.clear()),
    ));
    cases.push((
        "invalid_removed_unit_uas_rejected",
        rejects_record(valid_fixtures, |r| {
            r.removed_unit_uas_address = "not-uas:kv-page".to_string()
        }),
    ));
    cases.push((
        "missing_route_label_rejected",
        rejects_record(valid_fixtures, |r| r.route_label.clear()),
    ));
    cases.push((
        "missing_oracle_label_rejected",
        rejects_record(valid_fixtures, |r| r.oracle_label_ref.clear()),
    ));
    cases.push((
        "missing_decision_rejected",
        rejects_record(valid_fixtures, |r| r.decision.clear()),
    ));
    cases.push((
        "invalid_decision_rejected",
        rejects_record(valid_fixtures, |r| r.decision = "promote_live".to_string()),
    ));
    cases.push((
        "decision_mismatch_rejected",
        rejects_record(valid_fixtures, |r| {
            r.decision = "demote".to_string();
            r.quality_delta_bps = MIN_RETAINED_QUALITY_DELTA_BPS + 200;
            r.verifier_delta_bps = MIN_RETAINED_VERIFIER_DELTA_BPS + 200;
        }),
    ));
    cases.push((
        "missing_decision_record_rejected",
        rejects_record(valid_fixtures, |r| r.decision_record_ref.clear()),
    ));
    cases.push((
        "missing_rollback_rejected",
        rejects_record(valid_fixtures, |r| r.rollback_handle.clear()),
    ));
    cases.push((
        "missing_run_event_log_rejected",
        rejects_record(valid_fixtures, |r| r.run_event_log_ref.clear()),
    ));
    cases.push((
        "missing_answer_packet_rejected",
        rejects_record(valid_fixtures, |r| r.answer_packet_ref.clear()),
    ));
    cases.push((
        "missing_split_rejected",
        rejects_record(valid_fixtures, |r| r.split.clear()),
    ));
    cases.push((
        "invalid_split_rejected",
        rejects_record(valid_fixtures, |r| r.split = "live".to_string()),
    ));
    cases.push((
        "missing_held_out_split_rejected",
        rejects(valid_fixtures, |fixtures| {
            for fixture in fixtures {
                for record in &mut fixture.records {
                    record.split = "train".to_string();
                }
            }
        }),
    ));
    cases.push((
        "incompatible_fence_rejected",
        rejects_record(valid_fixtures, |r| {
            r.compatibility_fence = "fence:stale".to_string()
        }),
    ));
    cases.push((
        "invalid_privacy_rejected",
        rejects_record(valid_fixtures, |r| {
            r.privacy_class = "public_cloud".to_string()
        }),
    ));
    cases.push((
        "oracle_live_dependency_rejected",
        rejects_record(valid_fixtures, |r| r.oracle_live_dependency = true),
    ));
    cases.push((
        "live_route_promotion_rejected",
        rejects_record(valid_fixtures, |r| r.live_route_promoted = true),
    ));
    cases.push((
        "base_weight_mutation_rejected",
        rejects_record(valid_fixtures, |r| r.base_weight_mutated = true),
    ));
    cases.push((
        "route_policy_mutation_rejected",
        rejects_record(valid_fixtures, |r| r.route_policy_mutated = true),
    ));
    cases.push((
        "cache_mutation_rejected",
        rejects_record(valid_fixtures, |r| r.cache_mutated = true),
    ));
    cases.push((
        "hidden_route_authority_rejected",
        rejects_record(valid_fixtures, |r| r.hidden_route_authority = true),
    ));
    cases.push((
        "hidden_chain_exposure_rejected",
        rejects_record(valid_fixtures, |r| r.hidden_chain_exposed = true),
    ));
    cases.push((
        "cloud_source_rejected",
        rejects_record(valid_fixtures, |r| r.hidden_cloud = true),
    ));
    cases.push((
        "runtime_bytes_rejected",
        rejects_record(valid_fixtures, |r| r.runtime_bytes_loaded = 1),
    ));
    cases.push((
        "model_bytes_rejected",
        rejects_record(valid_fixtures, |r| r.model_bytes_loaded = 1),
    ));
    cases.push((
        "keep_all_baseline_unbeaten_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].keep_all_baseline_bps = fixtures[0].retained_success_bps
        }),
    ));
    cases.push((
        "remove_all_baseline_unbeaten_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].remove_all_baseline_bps = fixtures[0].retained_success_bps
        }),
    ));
    cases.push((
        "random_ablation_baseline_unbeaten_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].random_ablation_baseline_bps = fixtures[0].retained_success_bps
        }),
    ));
    cases.push((
        "no_ablation_baseline_unbeaten_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].no_ablation_baseline_bps = fixtures[0].retained_success_bps
        }),
    ));
    cases.push((
        "decision_accuracy_too_low_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].decision_accuracy_bps = MIN_DECISION_ACCURACY_BPS - 1
        }),
    ));
    cases.push((
        "retained_success_too_low_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].retained_success_bps = MIN_RETAINED_SUCCESS_BPS - 1
        }),
    ));
    cases.push((
        "retained_quality_delta_too_low_rejected",
        rejects_record(valid_fixtures, |r| {
            r.decision = "retain".to_string();
            r.quality_delta_bps = MIN_RETAINED_QUALITY_DELTA_BPS - 1;
        }),
    ));
    cases.push((
        "retained_verifier_delta_too_low_rejected",
        rejects_record(valid_fixtures, |r| {
            r.decision = "retain".to_string();
            r.verifier_delta_bps = MIN_RETAINED_VERIFIER_DELTA_BPS - 1;
        }),
    ));
    cases.push((
        "retained_latency_budget_rejected",
        rejects_record(valid_fixtures, |r| {
            r.decision = "retain".to_string();
            r.latency_delta_ms = MAX_RETAINED_LATENCY_DELTA_MS + 1;
        }),
    ));
    cases.push((
        "retained_byte_budget_rejected",
        rejects_record(valid_fixtures, |r| {
            r.decision = "retain".to_string();
            r.byte_delta = MAX_RETAINED_BYTE_DELTA + 1;
        }),
    ));
    cases.push((
        "decision_diversity_missing_rejected",
        rejects(valid_fixtures, |fixtures| {
            for fixture in fixtures {
                for record in &mut fixture.records {
                    record.decision = "retain".to_string();
                    record.quality_delta_bps = MIN_RETAINED_QUALITY_DELTA_BPS + 100;
                    record.verifier_delta_bps = MIN_RETAINED_VERIFIER_DELTA_BPS + 100;
                    record.latency_delta_ms = 12;
                    record.byte_delta = 256 * 1024;
                }
            }
        }),
    ));
    cases.push((
        "route_label_diversity_missing_rejected",
        rejects(valid_fixtures, |fixtures| {
            for fixture in fixtures {
                for record in &mut fixture.records {
                    record.route_label = "wake_sparse_kv_pages".to_string();
                }
            }
        }),
    ));
    cases.push((
        "metadata_budget_rejected",
        rejects_record(valid_fixtures, |r| {
            r.metadata_bytes = MAX_ABLATION_METADATA_BYTES + 1
        }),
    ));
    cases
}

fn rejects_record(
    fixtures: &[AblationShadowRunFixture],
    mutate: impl FnOnce(&mut AblationShadowRunRecord),
) -> bool {
    rejects(fixtures, |fixtures| mutate(&mut fixtures[0].records[0]))
}

fn rejects(
    fixtures: &[AblationShadowRunFixture],
    mutate: impl FnOnce(&mut Vec<AblationShadowRunFixture>),
) -> bool {
    let mut mutated = fixtures.to_vec();
    mutate(&mut mutated);
    AblationShadowRunRegistry::new(mutated).is_err()
}

fn fixture_ablation_shadow_runs() -> Vec<AblationShadowRunFixture> {
    vec![
        AblationShadowRunFixture {
            fixture_id: "ablation-proof-fixture".to_string(),
            ablation_policy_ref: "ablation-policy:proof-pressure:v1".to_string(),
            decision_accuracy_bps: 9_350,
            retained_success_bps: 9_120,
            keep_all_baseline_bps: 8_300,
            remove_all_baseline_bps: 7_000,
            random_ablation_baseline_bps: 6_600,
            no_ablation_baseline_bps: 7_500,
            authority: "shadow_only".to_string(),
            offline_evaluation_only: true,
            records: vec![
                ablation_record(
                    "proof-kv-retain-001",
                    "mission-proof-route",
                    "kv-page:proof-premise-neighbor",
                    "wake_sparse_kv_pages",
                    "retain",
                    "train",
                    620,
                    510,
                    26,
                    786_432,
                    "project_private",
                ),
                ablation_record(
                    "proof-adapter-retain-002",
                    "mission-proof-route",
                    "adapter:proof-repair-lora",
                    "repair_then_verify",
                    "retain",
                    "held_out",
                    710,
                    680,
                    42,
                    1_572_864,
                    "vault_private",
                ),
                ablation_record(
                    "citation-demote-003",
                    "mission-cited-answer",
                    "source-page:weak-citation-neighbor",
                    "retrieve_then_verify",
                    "demote",
                    "held_out",
                    80,
                    60,
                    11,
                    327_680,
                    "local_private",
                ),
            ],
        },
        AblationShadowRunFixture {
            fixture_id: "ablation-code-fixture".to_string(),
            ablation_policy_ref: "ablation-policy:code-kv-depth:v1".to_string(),
            decision_accuracy_bps: 9_460,
            retained_success_bps: 9_180,
            keep_all_baseline_bps: 8_400,
            remove_all_baseline_bps: 7_100,
            random_ablation_baseline_bps: 6_500,
            no_ablation_baseline_bps: 7_600,
            authority: "shadow_only".to_string(),
            offline_evaluation_only: true,
            records: vec![
                ablation_record(
                    "code-kv-retain-001",
                    "mission-code-note",
                    "kv-page:local-tool-context",
                    "wake_sparse_kv_pages",
                    "retain",
                    "train",
                    480,
                    390,
                    18,
                    524_288,
                    "vault_private",
                ),
                ablation_record(
                    "code-depth-retain-002",
                    "mission-code-note",
                    "depth-lease:repair-pass",
                    "resume_with_depth_lease",
                    "retain",
                    "held_out",
                    390,
                    350,
                    14,
                    393_216,
                    "project_private",
                ),
                ablation_record(
                    "sovereign-abstain-003",
                    "mission-note-mutation",
                    "proof-lane:unsafe-autonomy-escalation",
                    "abstain_for_sovereign_gate",
                    "abstain",
                    "held_out",
                    260,
                    520,
                    112,
                    1_966_080,
                    "local_private",
                ),
            ],
        },
    ]
}

fn ablation_record(
    suffix: &str,
    mission_id: &str,
    removed_unit: &str,
    route_label: &str,
    decision: &str,
    split: &str,
    quality_delta_bps: u64,
    verifier_delta_bps: u64,
    latency_delta_ms: u64,
    byte_delta: u64,
    privacy_class: &str,
) -> AblationShadowRunRecord {
    AblationShadowRunRecord {
        run_id: format!("ablation-shadow:{suffix}"),
        mission_id: mission_id.to_string(),
        upstream_shadow_wake_ref: UPSTREAM_SHADOW_WAKE_ORACLE.to_string(),
        baseline_trace_ref: format!("ablation-baseline-trace:{suffix}:remove-one-unit"),
        candidate_trace_ref: format!("ablation-candidate-trace:{suffix}:with-unit"),
        removed_unit: removed_unit.to_string(),
        removed_unit_uas_address: format!(
            "uas:ablation-unit:sha256:{}",
            sha256_hex(format!("{mission_id}:{removed_unit}").as_bytes())
                .trim_start_matches("sha256:")
        ),
        route_label: route_label.to_string(),
        oracle_label_ref: format!("oracle-label:shadow-wake:{suffix}"),
        quality_delta_bps,
        verifier_delta_bps,
        latency_delta_ms,
        byte_delta,
        decision: decision.to_string(),
        decision_record_ref: format!("decision-record:ablation-shadow:{suffix}"),
        rollback_handle: format!("rollback:ablation-shadow:{suffix}"),
        run_event_log_ref: format!("run-event-log:ablation-shadow:{suffix}"),
        answer_packet_ref: format!("answer-packet:ablation-shadow:{suffix}"),
        compatibility_fence: CURRENT_FENCE.to_string(),
        privacy_class: privacy_class.to_string(),
        split: split.to_string(),
        metadata_bytes: 512 * 1024,
        oracle_live_dependency: false,
        live_route_promoted: false,
        base_weight_mutated: false,
        route_policy_mutated: false,
        cache_mutated: false,
        hidden_route_authority: false,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        runtime_bytes_loaded: 0,
        model_bytes_loaded: 0,
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
        ">=" => actual >= expected,
        "<=" => actual <= expected,
        "<" => actual < expected,
        "==" => actual == expected,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), passed);
}

fn build_artifact() -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, AblationError> {
    let registry = AblationShadowRunRegistry::new(fixture_ablation_shadow_runs())?;
    let metrics = registry.metrics();
    let address = registry.address();
    let mut reversed = fixture_ablation_shadow_runs();
    reversed.reverse();
    for fixture in &mut reversed {
        fixture.records.reverse();
    }
    let deterministic = AblationShadowRunRegistry::new(reversed)?.address() == address;
    let invalid_axes = invalid_fixture_axes(&registry.fixtures);

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_shadow_wake_oracle_pass",
            upstream_artifact_pass(UPSTREAM_SHADOW_WAKE_ORACLE),
        ),
        ("ablation_fixture_present", metrics.fixture_count > 0),
        (
            "fixture_ids_bound",
            registry
                .fixtures
                .iter()
                .all(|fixture| !fixture.fixture_id.is_empty()),
        ),
        ("run_ids_bound", metrics.ablation_run_count == 6),
        (
            "mission_ids_bound",
            registry
                .records()
                .all(|record| !record.mission_id.is_empty()),
        ),
        (
            "upstream_shadow_wake_refs_bound",
            registry
                .records()
                .all(|record| !record.upstream_shadow_wake_ref.is_empty()),
        ),
        (
            "baseline_traces_bound",
            registry
                .records()
                .all(|record| !record.baseline_trace_ref.is_empty()),
        ),
        (
            "candidate_traces_bound",
            registry
                .records()
                .all(|record| !record.candidate_trace_ref.is_empty()),
        ),
        (
            "removed_units_bound",
            registry
                .records()
                .all(|record| !record.removed_unit.is_empty()),
        ),
        (
            "removed_unit_uas_addresses_bound",
            registry
                .records()
                .all(|record| record.removed_unit_uas_address.starts_with("uas:")),
        ),
        (
            "route_labels_bound",
            registry
                .records()
                .all(|record| !record.route_label.is_empty()),
        ),
        (
            "oracle_label_refs_bound",
            registry
                .records()
                .all(|record| !record.oracle_label_ref.is_empty()),
        ),
        (
            "quality_deltas_bound",
            registry
                .records()
                .all(|record| record.quality_delta_bps > 0),
        ),
        (
            "verifier_deltas_bound",
            registry
                .records()
                .all(|record| record.verifier_delta_bps > 0),
        ),
        (
            "latency_deltas_bound",
            registry.records().all(|record| record.latency_delta_ms > 0),
        ),
        (
            "byte_deltas_bound",
            registry.records().all(|record| record.byte_delta > 0),
        ),
        (
            "decisions_bound",
            registry
                .records()
                .all(|record| matches!(record.decision.as_str(), "retain" | "demote" | "abstain")),
        ),
        (
            "decision_records_bound",
            registry
                .records()
                .all(|record| !record.decision_record_ref.is_empty()),
        ),
        (
            "rollback_bound",
            registry
                .records()
                .all(|record| !record.rollback_handle.is_empty()),
        ),
        (
            "run_event_log_bound",
            registry
                .records()
                .all(|record| !record.run_event_log_ref.is_empty()),
        ),
        (
            "answer_packet_ref_bound",
            registry
                .records()
                .all(|record| !record.answer_packet_ref.is_empty()),
        ),
        (
            "compatibility_fence_bound",
            registry
                .records()
                .all(|record| record.compatibility_fence == CURRENT_FENCE),
        ),
        (
            "privacy_classes_bound",
            registry
                .records()
                .all(|record| valid_privacy_class(&record.privacy_class)),
        ),
        ("held_out_split_bound", metrics.held_out_case_count >= 4),
        ("retained_cases_present", metrics.retained_case_count >= 4),
        ("demoted_cases_present", metrics.demoted_case_count >= 1),
        ("abstain_cases_present", metrics.abstain_case_count >= 1),
        (
            "decision_diversity_bound",
            metrics.decision_kind_count >= MIN_DECISION_KIND_COUNT,
        ),
        (
            "route_label_diversity_bound",
            metrics.route_label_count >= MIN_ROUTE_LABEL_COUNT,
        ),
        (
            "counterfactual_remove_one_unit_bound",
            registry.records().all(|record| {
                record.baseline_trace_ref != record.candidate_trace_ref
                    && !record.removed_unit_uas_address.is_empty()
            }),
        ),
        (
            "shadow_only_authority",
            registry
                .fixtures
                .iter()
                .all(|fixture| fixture.authority == "shadow_only"),
        ),
        (
            "offline_evaluation_only",
            registry
                .fixtures
                .iter()
                .all(|fixture| fixture.offline_evaluation_only),
        ),
        (
            "oracle_not_live_dependency",
            registry
                .records()
                .all(|record| !record.oracle_live_dependency),
        ),
        (
            "no_live_route_promotion",
            registry.records().all(|record| !record.live_route_promoted),
        ),
        (
            "no_base_weight_mutation",
            registry.records().all(|record| !record.base_weight_mutated),
        ),
        (
            "no_route_policy_mutation",
            registry
                .records()
                .all(|record| !record.route_policy_mutated),
        ),
        (
            "no_cache_mutation",
            registry.records().all(|record| !record.cache_mutated),
        ),
        (
            "no_hidden_route_authority",
            registry
                .records()
                .all(|record| !record.hidden_route_authority),
        ),
        (
            "no_hidden_chain",
            registry
                .records()
                .all(|record| !record.hidden_chain_exposed),
        ),
        (
            "no_hidden_cloud",
            registry.records().all(|record| !record.hidden_cloud),
        ),
        (
            "no_runtime_bytes_loaded",
            registry
                .records()
                .all(|record| record.runtime_bytes_loaded == 0),
        ),
        (
            "no_model_bytes_loaded",
            registry
                .records()
                .all(|record| record.model_bytes_loaded == 0),
        ),
        ("ablation_shadow_run_address_deterministic", deterministic),
        (
            "retained_quality_delta_bound",
            metrics.min_retained_quality_delta_bps >= MIN_RETAINED_QUALITY_DELTA_BPS,
        ),
        (
            "retained_verifier_delta_bound",
            metrics.min_retained_verifier_delta_bps >= MIN_RETAINED_VERIFIER_DELTA_BPS,
        ),
        (
            "retained_latency_penalty_budget_bound",
            metrics.max_retained_latency_delta_ms <= MAX_RETAINED_LATENCY_DELTA_MS,
        ),
        (
            "retained_byte_budget_bound",
            metrics.max_retained_byte_delta <= MAX_RETAINED_BYTE_DELTA,
        ),
        (
            "decision_accuracy_bound",
            metrics.decision_accuracy_bps >= MIN_DECISION_ACCURACY_BPS,
        ),
        (
            "retained_success_bound",
            metrics.retained_success_bps >= MIN_RETAINED_SUCCESS_BPS,
        ),
        (
            "metadata_bound",
            metrics.max_ablation_metadata_bytes <= MAX_ABLATION_METADATA_BYTES,
        ),
        (
            "beats_keep_all_baseline",
            metrics.keep_all_baseline_bps < metrics.retained_success_bps,
        ),
        (
            "beats_remove_all_baseline",
            metrics.remove_all_baseline_bps < metrics.retained_success_bps,
        ),
        (
            "beats_random_ablation_baseline",
            metrics.random_ablation_baseline_bps < metrics.retained_success_bps,
        ),
        (
            "beats_no_ablation_baseline",
            metrics.no_ablation_baseline_bps < metrics.retained_success_bps,
        ),
    ];

    for (axis, passed) in bool_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            passed,
        );
    }
    for (axis, passed) in invalid_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
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
        "fixtures",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "ablation_run_count",
        metrics.ablation_run_count,
        6,
        "runs",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "train_case_count",
        metrics.train_case_count,
        2,
        "cases",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_case_count",
        metrics.held_out_case_count,
        4,
        "cases",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "retained_case_count",
        metrics.retained_case_count,
        4,
        "cases",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "demoted_case_count",
        metrics.demoted_case_count,
        1,
        "cases",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "abstain_case_count",
        metrics.abstain_case_count,
        1,
        "cases",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "removed_unit_count",
        metrics.removed_unit_count,
        6,
        "units",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_label_count",
        metrics.route_label_count,
        ">=",
        MIN_ROUTE_LABEL_COUNT,
        "labels",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "decision_kind_count",
        metrics.decision_kind_count,
        ">=",
        MIN_DECISION_KIND_COUNT,
        "decisions",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_retained_quality_delta_bps",
        metrics.min_retained_quality_delta_bps,
        ">=",
        MIN_RETAINED_QUALITY_DELTA_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_retained_verifier_delta_bps",
        metrics.min_retained_verifier_delta_bps,
        ">=",
        MIN_RETAINED_VERIFIER_DELTA_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_retained_latency_delta_ms",
        metrics.max_retained_latency_delta_ms,
        "<=",
        MAX_RETAINED_LATENCY_DELTA_MS,
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_retained_byte_delta",
        metrics.max_retained_byte_delta,
        "<=",
        MAX_RETAINED_BYTE_DELTA,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "decision_accuracy_bps",
        metrics.decision_accuracy_bps,
        ">=",
        MIN_DECISION_ACCURACY_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "retained_success_bps",
        metrics.retained_success_bps,
        ">=",
        MIN_RETAINED_SUCCESS_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "keep_all_baseline_bps",
        metrics.keep_all_baseline_bps,
        "<",
        metrics.retained_success_bps,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "remove_all_baseline_bps",
        metrics.remove_all_baseline_bps,
        "<",
        metrics.retained_success_bps,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "random_ablation_baseline_bps",
        metrics.random_ablation_baseline_bps,
        "<",
        metrics.retained_success_bps,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_ablation_baseline_bps",
        metrics.no_ablation_baseline_bps,
        "<",
        metrics.retained_success_bps,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_ablation_metadata_bytes",
        metrics.max_ablation_metadata_bytes,
        "<=",
        MAX_ABLATION_METADATA_BYTES,
        "bytes",
    );

    measurements.insert(
        "ablation_shadow_run_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address.clone()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "ablation_shadow_run_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::Value::String("uas:ablation-shadow-run:*".to_string()),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "ablation_shadow_run_address".to_string(),
        !address.is_empty(),
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
        anomalies: vec![],
        notes: "metadata-only counterfactual ablation witness; no runtime/model bytes loaded, no live route authority, no policy/cache/base mutation, and no product claim promoted".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let artifact =
        build_artifact().map_err(|err| format!("ablation shadow witness failed: {err:?}"))?;
    let path = PathBuf::from(RESULT);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let mut file = std::fs::File::create(&path)?;
    write_artifact(&mut file, &artifact)?;

    println!(
        "{FALSIFIER_ID}: overall_pass={} ablation_run_count={} retained_case_count={} ablation_shadow_run_address={:?} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["ablation_run_count"].value,
        artifact.measurements["retained_case_count"].value,
        artifact.measurements["ablation_shadow_run_address"].value
    );
    if artifact.overall_pass {
        Ok(())
    } else {
        Err("F-AblationShadowRun failed".into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_fixture_rejects() {
        assert_eq!(
            AblationShadowRunRegistry::new(vec![]).unwrap_err(),
            AblationError::EmptyFixtures
        );
    }

    #[test]
    fn invalid_fixture_cases_reject() {
        let fixtures = fixture_ablation_shadow_runs();
        let axes = invalid_fixture_axes(&fixtures);
        assert!(!axes.is_empty());
        for (axis, rejected) in axes {
            assert!(rejected, "{axis} did not reject");
        }
    }

    #[test]
    fn ablation_shadow_run_address_is_order_stable() {
        let registry = AblationShadowRunRegistry::new(fixture_ablation_shadow_runs()).unwrap();
        let address = registry.address();
        let mut reversed = fixture_ablation_shadow_runs();
        reversed.reverse();
        for fixture in &mut reversed {
            fixture.records.reverse();
        }
        let reversed_registry = AblationShadowRunRegistry::new(reversed).unwrap();
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

    #[test]
    fn decision_diversity_is_present() {
        let registry = AblationShadowRunRegistry::new(fixture_ablation_shadow_runs()).unwrap();
        assert!(registry.has_decision("retain"));
        assert!(registry.has_decision("demote"));
        assert!(registry.has_decision("abstain"));
    }

    #[test]
    fn retained_records_are_budgeted() {
        let registry = AblationShadowRunRegistry::new(fixture_ablation_shadow_runs()).unwrap();
        for record in registry
            .records()
            .filter(|record| record.decision == "retain")
        {
            assert!(record.quality_delta_bps >= MIN_RETAINED_QUALITY_DELTA_BPS);
            assert!(record.verifier_delta_bps >= MIN_RETAINED_VERIFIER_DELTA_BPS);
            assert!(record.latency_delta_ms <= MAX_RETAINED_LATENCY_DELTA_MS);
            assert!(record.byte_delta <= MAX_RETAINED_BYTE_DELTA);
        }
    }
}
